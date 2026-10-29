import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import MinMaxCalDomain
import Testing

@Test(arguments: [false, true], [false, true])
func `join defaults to recording only when enabled and selected`(enabled: Bool, recordOnJoin: Bool) async throws {
    let now = Date.now
    let item = try AgendaItem(
        members: [.init(calendarItemIdentifier: "join")],
        kind: .event,
        title: "Planning",
        start: now.addingTimeInterval(-60),
        end: now.addingTimeInterval(600),
        joinLink: JoinLinkDetector.classify(#require(URL(string: "https://zoom.us/j/123456789"))),
    )
    let events = AgendaMeetingCalendar.meetings(in: Agenda(
        items: [item],
        horizon: DateInterval(start: now, duration: 86_400),
    ))
    let recorder = Recorder()
    let suite = "MinMaxCalCoaching-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = CoachingController(defaults: defaults, makeModel: {
        MeetingModel(
            recorder: recorder,
            store: Store(),
            speechModels: Models(),
            calendar: CalendarSource(events: events),
        )
    })
    #expect(controller.recordOnJoin)
    controller.recordOnJoin = recordOnJoin
    if enabled {
        await controller.setEnabled(true)
        try await waitFor { controller.canRecord }
    }
    var opened = [JoinLink]()
    var refreshes = 0
    await controller.join(item, using: { opened.append($0) }, refresh: { refreshes += 1 })
    #expect(opened == [item.joinLink].compactMap(\.self))
    if enabled, recordOnJoin {
        try await waitFor { controller.model?.phase == .recording }
        #expect(recorder.starts == 1)
        #expect(refreshes == 1)
    } else {
        #expect(recorder.starts == 0)
        #expect(refreshes == 0)
    }
    await controller.setEnabled(false)
    #expect(controller.model == nil)
    #expect(defaults.bool(forKey: "coaching.recordOnJoin") == recordOnJoin)
}

@Test(arguments: ["https://zoom.us/j/123456789", "https://example.com/call"], [-60.0, 60.0])
func `explicit join and record revalidates the event and starts once`(
    address: String,
    startsIn: TimeInterval,
) async throws {
    let now = Date.now
    let item = try AgendaItem(
        members: [.init(calendarItemIdentifier: "call")],
        kind: .event,
        title: "Planning",
        start: now.addingTimeInterval(startsIn),
        end: now.addingTimeInterval(600),
        joinLink: JoinLinkDetector.classify(#require(URL(string: address))),
    )
    let events = AgendaMeetingCalendar.meetings(in: Agenda(
        items: [item],
        horizon: DateInterval(start: now, duration: 86_400),
    ))
    let recorder = Recorder()
    let suite = "MinMaxCalCoaching-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = CoachingController(defaults: defaults, makeModel: {
        MeetingModel(
            recorder: recorder,
            store: Store(),
            speechModels: Models(),
            calendar: CalendarSource(events: events),
        )
    })
    await controller.record(item)
    #expect(controller.model == nil)
    #expect(controller.canRecord == false)
    await controller.setEnabled(true)
    try await waitFor { controller.canRecord }
    let model = try #require(controller.model)
    #expect(model.phase == .idle)
    await controller.record(item)
    try await waitFor { model.phase == .recording }
    await controller.record(item)
    #expect(recorder.starts == 1)
    #expect(model.current?.title == item.title)
    #expect(controller.showingMeeting)
    await controller.setEnabled(false)
}

@Test
func `join and record does not capture a deleted event`() async throws {
    let now = Date.now
    let item = try AgendaItem(
        members: [.init(calendarItemIdentifier: "deleted")],
        kind: .event,
        title: "Deleted meeting",
        start: now.addingTimeInterval(-60),
        end: now.addingTimeInterval(600),
        joinLink: JoinLinkDetector.classify(#require(URL(string: "https://zoom.us/j/123456789"))),
    )
    let recorder = Recorder()
    let suite = "MinMaxCalCoaching-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let controller = CoachingController(defaults: defaults, makeModel: {
        MeetingModel(recorder: recorder, store: Store(), speechModels: Models(), calendar: CalendarSource(events: []))
    })
    await controller.setEnabled(true)
    try await waitFor { controller.canRecord }
    await controller.record(item)
    #expect(recorder.starts == 0)
    #expect(controller.model?.error != nil)
    #expect(controller.showingMeeting)
    await controller.setEnabled(false)
}
