import AppIntents
import Foundation
import MinMaxCalData
import MinMaxCalDomain
import MinMaxCalFeatures
@testable import MinMaxCalIntents
import Testing

/// Each intent's dependencies are set by hand, since `AppDependencyManager` resolves them only inside
/// the framework's own perform flow; a set value lands in the shared manager by type, so the suite
/// runs serialised.
@Suite(.serialized)
struct IntentsTests {
    // MARK: Lifecycle

    init() throws {
        settings = try Fixtures.settingsStore()
        agenda = AgendaModel(source: source, settings: settings, opener: opener, clock: Fixtures.clock)
        takeover = TakeoverModel(
            source: source,
            opener: opener,
            ledger: Fixtures.ledgerStore(),
            settings: settings,
            presenter: presenter,
            clock: Fixtures.clock,
        )
    }

    // MARK: Internal

    @Test
    func `get next item returns the menu bar's item and nothing the invitation wrote`() async throws {
        let link = try JoinLink(service: .meet, url: #require(URL(string: "https://meet.google.com/abc")))
        var planning = Fixtures.event("planning", title: "Weekly planning", startingIn: 10, link: link)
        planning.notes = "Secret notes"
        planning.location = "Room 1"
        source.items = [planning]
        await agenda.rebuild()

        let entity = try #require(await getNextItem().perform().value)

        #expect(entity.title == "Weekly planning")
        #expect(entity.kind == "Event")
        #expect(entity.start == planning.start)
        #expect(entity.countdown == "10m")
        #expect(entity.joinURL == link.url)
        #expect(Mirror(reflecting: entity).children.contains { "\($0.value)".contains("Secret") } == false)
        let query = AgendaItemQuery()
        query.$agenda.wrappedValue = agenda
        #expect(await query.entities(for: [entity.id]).map(\.id) == [entity.id])
    }

    @Test
    func `get next item says when nothing is coming up`() async {
        await agenda.rebuild()
        await #expect(throws: IntentError.nothingUpcoming) { try await getNextItem().perform() }
    }

    @Test
    func `join next meeting opens the next call in the chosen app`() async throws {
        let link = try JoinLink(service: .zoom, url: #require(URL(string: "https://zoom.us/j/1")))
        source.items = [Fixtures.event("focus", startingIn: 5), Fixtures.event("call", startingIn: 20, link: link)]
        await agenda.rebuild()

        _ = try await joinNextMeeting().perform()

        #expect(opener.opened == [link])
        #expect(opener.openedIn == [JoinApp.zoom.bundleIdentifier])
        source.items = []
        await agenda.rebuild()
        await #expect(throws: IntentError.noCall) { try await joinNextMeeting().perform() }
    }

    @Test
    func `complete next reminder ticks the overdue one and reports a failed save`() async throws {
        let overdue = Fixtures.reminder("overdue", dueIn: -120)
        source.items = [overdue, Fixtures.reminder("later", dueIn: 30)]
        await agenda.rebuild()

        _ = try await completeNextReminder().perform()
        #expect(source.completed == overdue.members)

        source.completionError = FakeError()
        await #expect(throws: IntentError.self) { try await completeNextReminder().perform() }
        source.items = []
        await agenda.rebuild()
        await #expect(throws: IntentError.noReminder) { try await completeNextReminder().perform() }
    }

    @Test
    func `snooze takeover needs a reminder takeover and a configured duration`() async throws {
        let reminder = Fixtures.reminder("reminder", dueIn: 0)
        await #expect(throws: IntentError.noReminderTakeover) { try await snooze(minutes: 15) }
        takeover.present(Takeover(entries: [Takeover.Entry(item: reminder, trigger: .due)], moment: reminder.start))
        let options = SnoozeMinutesOptions()
        options.$takeover.wrappedValue = takeover
        #expect(await options.results() == [5, 15, 60])
        await #expect(throws: IntentError.noReminderTakeover) { try await snooze(minutes: 7) }

        _ = try await snooze(minutes: 15)

        #expect(takeover.current == nil)
        takeover.schedule(agenda: Agenda(items: [reminder], horizon: DateInterval()), now: Fixtures.now)
        #expect(takeover.planned?.moment == Fixtures.now.addingTimeInterval(15 * 60))
    }

    @Test
    func `preview takeover shows the next item without recording it`() async throws {
        source.items = [Fixtures.event("event", startingIn: 5)]
        await agenda.rebuild()

        let preview = PreviewTakeoverIntent()
        preview.$agenda.wrappedValue = agenda
        preview.$takeover.wrappedValue = takeover
        _ = try await preview.perform()

        #expect(takeover.current?.isPreview == true)
        #expect(presenter.shown == 1)
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let opener: FakeLinkOpener = .init()
    private let presenter: FakePresenter = .init()
    private let settings: SettingsStore
    private let agenda: AgendaModel
    private let takeover: TakeoverModel

    private func getNextItem() -> GetNextItemIntent {
        let intent = GetNextItemIntent()
        intent.$agenda.wrappedValue = agenda
        return intent
    }

    private func joinNextMeeting() -> JoinNextMeetingIntent {
        let intent = JoinNextMeetingIntent()
        intent.$agenda.wrappedValue = agenda
        return intent
    }

    private func completeNextReminder() -> CompleteNextReminderIntent {
        let intent = CompleteNextReminderIntent()
        intent.$agenda.wrappedValue = agenda
        return intent
    }

    private func snooze(minutes: Int) async throws -> some IntentResult {
        let intent = SnoozeTakeoverIntent()
        intent.$takeover.wrappedValue = takeover
        intent.minutes = minutes
        return try await intent.perform()
    }
}
