import Foundation
@testable import MinMaxCalCoachingFeatures
import MinMaxCalDomain
import Testing

@Test
func `record choices include every event with a join button`() throws {
    let now = Date.now
    let link = try #require(JoinLinkDetector.detect(
        url: URL(string: "https://meet.jit.si/Planning"),
        location: nil,
        notes: nil,
    ))
    var meeting = AgendaItem(
        members: [.init(calendarItemIdentifier: "event", occurrenceDate: now)],
        kind: .event,
        title: "Planning",
        start: now,
        end: now.addingTimeInterval(600),
        attendees: [.init(name: "Alex", response: .accepted)],
        joinLink: link,
    )
    func inferred(_ item: AgendaItem) -> [String] {
        AgendaMeetingCalendar.meetings(in: Agenda(
            items: AgendaFilter.upcoming([item], now: now),
            horizon: DateInterval(
                start: now,
                duration: 86_400,
            ),
        ))
        .map(\.title)
    }
    #expect(inferred(meeting) == ["Planning"])
    meeting.attendees = [.init(name: "Room", response: .accepted, isPerson: false)]
    #expect(inferred(meeting) == ["Planning"])
    meeting.organiser = .init(name: "Alex", response: .accepted)
    meeting.attendees = []
    #expect(inferred(meeting) == ["Planning"])
    meeting.attendees = [.init(name: "Alex", response: .declined)]
    #expect(inferred(meeting) == ["Planning"])
    meeting.attendees = [.init(name: "Alex", response: .accepted)]
    meeting.joinLink = try JoinLinkDetector.classify(#require(URL(string: "https://example.com")))
    #expect(inferred(meeting) == ["Planning"])
    meeting.joinLink = link
    meeting.isAllDay = true
    #expect(inferred(meeting) == ["Planning"])
    meeting.isAllDay = false
    meeting.end = nil
    #expect(inferred(meeting) == ["Planning"])
    meeting.currentUserResponse = .declined
    #expect(inferred(meeting).isEmpty)
    meeting.currentUserResponse = .accepted
    meeting.kind = .reminder
    #expect(inferred(meeting).isEmpty)
    meeting.kind = .event
    meeting.joinLink = nil
    #expect(inferred(meeting).isEmpty)
}

@Test
func `record prompts distinguish recurring occurrences at the same start`() throws {
    let now = Date.now
    var item = try AgendaItem(
        members: [.init(calendarItemIdentifier: "recurring", occurrenceDate: now)],
        kind: .event,
        title: "Planning",
        start: now,
        end: now.addingTimeInterval(600),
        attendees: [.init(name: "Alex", response: .accepted)],
        joinLink: JoinLinkDetector.classify(#require(URL(string: "https://meet.jit.si/Planning"))),
    )
    var other = item
    other.members[0].occurrenceDate = now.addingTimeInterval(86_400)
    let agenda = Agenda(items: [item, other], horizon: DateInterval(start: now, duration: 86_400))
    let meetings = AgendaMeetingCalendar.meetings(in: agenda)
    #expect(Set(meetings.map(\.id)).count == 2)
    item.start = now.addingTimeInterval(60)
    let moved = AgendaMeetingCalendar.meetings(in: Agenda(items: [item], horizon: agenda.horizon))
    #expect(moved.first?.id != meetings.first?.id)
}

@Test(arguments: [
    "https://zoom.us/j/123456789",
    "https://meet.google.com/abc-defg-hij",
    "https://meet.jit.si/Planning",
    "https://teams.microsoft.com/meet/9876543210?p=AbC1",
    "https://facetime.apple.com/join#v=1&p=abc&k=def",
])
func `conference events qualify without attendee metadata`(address: String) throws {
    let now = Date.now
    let item = try AgendaItem(
        members: [.init(calendarItemIdentifier: "event")],
        kind: .event,
        title: "Planning",
        start: now,
        end: now.addingTimeInterval(600),
        joinLink: JoinLinkDetector.classify(#require(URL(string: address))),
    )
    let meetings = AgendaMeetingCalendar.meetings(in: Agenda(
        items: [item], horizon: DateInterval(start: now, duration: 86_400),
    ))
    #expect(meetings.count == 1)
    #expect(meetings.first?.participantNames.isEmpty == true)
}
