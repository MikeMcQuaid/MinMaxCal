import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct AgendaModelTests {
    // MARK: Lifecycle

    init() throws {
        store = try Fixtures.settingsStore()
        model = AgendaModel(source: source, settings: store, opener: opener, clock: Fixtures.clock)
    }

    // MARK: Internal

    @Test
    func `rebuild filters merges sorts and renders the title`() async {
        let busy = Fixtures.event("busy", title: "Busy", startingIn: 60)
        let planning = Fixtures.event("planning", title: "Weekly planning", startingIn: 60)
        let past = Fixtures.event("past", startingIn: -90)
        let reminder = Fixtures.reminder("reminder", title: "Call back", dueIn: 10)
        source.items = [busy, planning, past, reminder]
        var rebuilt: Agenda?
        model.onRebuild = { agenda, _ in rebuilt = agenda }

        await model.rebuild()

        #expect(model.agenda.items.map(\.title) == ["Call back", "Weekly planning"])
        #expect(model.agenda.items[1].members == busy.members + planning.members)
        #expect(model.title == "Call back 10m")
        #expect(model.hasSelection)
        #expect(rebuilt == model.agenda)
    }

    @Test
    func `an empty selection gives an empty agenda and no title`() async {
        store.selection = .empty
        source.items = [Fixtures.event("e")]

        await model.rebuild()

        #expect(model.agenda.items.isEmpty)
        #expect(model.title == nil)
        #expect(model.hasSelection == false)
    }

    @Test
    func `completing strikes the row through and can be undone for a while`() async throws {
        let reminder = Fixtures.reminder("reminder")
        source.items = [reminder]
        await model.rebuild()

        await model.complete(reminder)

        #expect(model.agenda.items.map(\.isCompleted) == [true])
        #expect(source.completed == reminder.members)
        #expect(model.errorMessage == nil)
        #expect(MenuBarTitle.render(agenda: model.agenda, now: Fixtures.now) == nil)

        source.items = []
        await model.rebuild()
        #expect(model.agenda.items.map(\.isCompleted) == [true])

        try await model.uncomplete(#require(model.agenda.items.first))
        #expect(source.completed.isEmpty)
        #expect(model.agenda.items.map(\.isCompleted) == [false])
    }

    @Test
    func `a completed row leaves after five minutes`() async {
        let reminder = Fixtures.reminder("reminder")
        source.items = [reminder]
        let timed = AgendaModel(source: source, settings: store, opener: opener, clock: clock.read)
        await timed.rebuild()
        await timed.complete(reminder)
        source.items = []

        clock.now = Fixtures.now.addingTimeInterval(4 * 60)
        await timed.rebuild()
        #expect(timed.agenda.items.count == 1)

        clock.now = Fixtures.now.addingTimeInterval(6 * 60)
        await timed.rebuild()
        #expect(timed.agenda.items.isEmpty)
    }

    @Test
    func `a failed completion restores the row with the error`() async {
        let reminder = Fixtures.reminder("reminder")
        source.items = [reminder]
        source.completionError = FakeError()
        await model.rebuild()

        await model.complete(reminder)

        #expect(model.agenda.items == [reminder])
        #expect(model.errorMessage == "Could not save.")
    }

    @Test
    func `a burst of refresh requests collapses into one rebuild`() async throws {
        let loop = Task { await model.run() }
        for _ in 0 ..< 20 {
            model.requestRefresh()
        }
        let deadline = ContinuousClock.now + .seconds(5)
        while source.fetches < 2, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        // Long enough for any queued rebuild to show up in the count.
        try await Task.sleep(for: .milliseconds(100))
        loop.cancel()

        #expect(source.fetches == 2, "the first rebuild, then one for the whole burst")
    }

    @Test
    func `exposes the next item the next call and the next reminder for the intents`() async throws {
        let link = try JoinLink(service: .meet, url: #require(URL(string: "https://meet.google.com/abc")))
        let overdue = Fixtures.reminder("overdue", dueIn: -120)
        let planning = Fixtures.event("planning", title: "Weekly planning", startingIn: 10)
        let call = Fixtures.event("call", title: "Standup", startingIn: 20, link: link)
        source.items = [overdue, planning, call]

        await model.rebuild()

        #expect(model.nextItem == planning, "an overdue reminder leaves the menu bar after an hour")
        #expect(model.nextCall == call)
        #expect(model.nextReminder == overdue)
    }

    @Test
    func `join opens through the port`() throws {
        let link = try JoinLink(service: .meet, url: #require(URL(string: "https://meet.google.com/abc")))
        model.join(link)
        #expect(opener.opened == [link])
        #expect(opener.openedIn == [JoinApp.edge.bundleIdentifier])
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let opener: FakeLinkOpener = .init()
    private let store: SettingsStore
    private let model: AgendaModel
    private let clock: AdjustableClock = .init()
}
