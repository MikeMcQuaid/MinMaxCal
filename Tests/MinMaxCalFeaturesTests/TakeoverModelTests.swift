import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct TakeoverModelTests {
    // MARK: Lifecycle

    init() throws {
        model = try TakeoverModel(
            source: source,
            opener: opener,
            ledger: ledger,
            settings: Fixtures.settingsStore(),
            presenter: presenter,
            clock: Fixtures.clock,
        )
    }

    // MARK: Internal

    @Test
    func `schedules the next takeover from the agenda`() {
        let event = Fixtures.event("event", startingIn: 5)
        model.schedule(agenda: agenda([event]), now: Fixtures.now)
        #expect(model.planned?.entries.first?.item == event)
        #expect(model.planned?.moment == event.start)
    }

    @Test
    func `dismiss records the ledger hides and notifies`() throws {
        let event = Fixtures.event("event", startingIn: 0)
        model.schedule(agenda: agenda([event]), now: Fixtures.now)
        let takeover = try #require(model.planned)
        var notified = 0
        model.onAction = { notified += 1 }

        model.present(takeover)
        #expect(presenter.shown == 1)
        #expect(model.current == takeover)

        model.dismiss()

        #expect(model.current == nil)
        #expect(presenter.hidden == 1)
        #expect(notified == 1)
        #expect(ledger.load().isDismissed(event, trigger: .start, moment: event.start))
        model.schedule(agenda: agenda([event]), now: Fixtures.now)
        #expect(model.planned == nil)
    }

    @Test
    func `join hides then opens the link`() throws {
        let link = try JoinLink(service: .zoom, url: #require(URL(string: "zoommtg://zoom.us/join?confno=1")))
        let event = Fixtures.event("event", startingIn: 0, link: link)
        model.present(Takeover(entries: [Takeover.Entry(item: event, trigger: .start)], moment: event.start))

        model.join(link)

        #expect(presenter.hidden == 1)
        #expect(opener.opened == [link])
    }

    @Test
    func `complete writes to reminders then dismisses`() async {
        let reminder = Fixtures.reminder("reminder", dueIn: 0)
        model.present(Takeover(entries: [Takeover.Entry(item: reminder, trigger: .due)], moment: reminder.start))

        await model.complete()

        #expect(source.completed == reminder.members)
        #expect(model.current == nil)
        #expect(presenter.hidden == 1)
    }

    @Test
    func `a failed completion keeps the panel with the error`() async {
        let reminder = Fixtures.reminder("reminder", dueIn: 0)
        source.completionError = FakeError()
        model.present(Takeover(entries: [Takeover.Entry(item: reminder, trigger: .due)], moment: reminder.start))

        await model.complete()

        #expect(model.current != nil)
        #expect(model.errorMessage == "Could not save.")
    }

    @Test
    func `snooze brings the reminder back later`() {
        let reminder = Fixtures.reminder("reminder", dueIn: 0)
        model.present(Takeover(entries: [Takeover.Entry(item: reminder, trigger: .due)], moment: reminder.start))

        model.snooze(minutes: 15)

        #expect(model.current == nil)
        model.schedule(agenda: agenda([reminder]), now: Fixtures.now)
        #expect(model.planned?.entries.first?.trigger == .snooze)
        #expect(model.planned?.moment == Fixtures.now.addingTimeInterval(15 * 60))
    }

    @Test
    func `previews never touch the ledger or reminders`() async {
        model.preview(.reminder)
        #expect(model.current?.isPreview == true)
        #expect(presenter.shown == 1)

        await model.complete()

        #expect(source.completed.isEmpty)
        #expect(ledger.load() == .empty)
        #expect(model.current == nil)
    }

    @Test
    func `a live takeover is never replaced by a preview`() {
        let event = Fixtures.event("event", startingIn: 0)
        let live = Takeover(entries: [Takeover.Entry(item: event, trigger: .start)], moment: event.start)
        model.present(live)

        model.preview(.zoomEvent)

        #expect(model.current == live)
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let opener: FakeLinkOpener = .init()
    private let presenter: FakePresenter = .init()
    private let ledger: TakeoverLedgerStore = Fixtures.ledgerStore()
    private let model: TakeoverModel

    private func agenda(_ items: [AgendaItem]) -> Agenda {
        Agenda(items: items, horizon: DateInterval(start: Fixtures.now, duration: 60 * 60))
    }
}
