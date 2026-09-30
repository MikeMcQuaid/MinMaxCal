import AppKit
import MinMaxCalData
@testable import MinMaxCalFeatures
import Testing

@Suite(.serialized)
struct SystemChangesTests {
    @Test(arguments: [
        NSWorkspace.didWakeNotification,
        NSWorkspace.screensDidWakeNotification,
        NSWorkspace.sessionDidBecomeActiveNotification,
    ])
    func `returning to the Mac hides a reminder completed while away`(name: Notification.Name) async throws {
        let source = FakeCalendarSource()
        let settings = try Fixtures.settingsStore()
        let presenter = FakePresenter()
        let ledger: TakeoverLedgerStore = Fixtures.ledgerStore()
        let takeover = TakeoverModel(
            source: source,
            opener: FakeLinkOpener(),
            ledger: ledger,
            settings: settings,
            presenter: presenter,
            clock: Fixtures.clock,
        )
        let agenda = AgendaModel(
            source: source,
            settings: settings,
            opener: FakeLinkOpener(),
            systemChanges: SystemChanges.stream,
            clock: Fixtures.clock,
        )
        agenda.onRebuild = takeover.schedule
        source.items = [Fixtures.reminder("reminder", dueIn: 0)]
        let loop = Task { await agenda.run() }
        defer { loop.cancel() }
        let shownDeadline = ContinuousClock.now + .seconds(5)
        while takeover.current == nil, ContinuousClock.now < shownDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(takeover.current != nil)
        source.items = []

        NSWorkspace.shared.notificationCenter.post(name: name, object: NSWorkspace.shared)

        let hiddenDeadline = ContinuousClock.now + .seconds(5)
        while takeover.current != nil, ContinuousClock.now < hiddenDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(takeover.current == nil)
        #expect(takeover.planned == nil)
        #expect(agenda.agenda.items.isEmpty)
        #expect(source.fetches == 2)
        #expect(presenter.focusReturns == [true])
        #expect(source.completed.isEmpty)
        #expect(ledger.load() == .empty)
        loop.cancel()
        await loop.value
    }

    @Test(arguments: [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged])
    func `yields when the clock is set the time zone changes or the day turns`(name: Notification.Name) async throws {
        let changes = SystemChanges.stream
        async let received = changes.prefix(1).reduce(0) { count, _ in count + 1 }
        try await Task.sleep(for: .milliseconds(100))
        NotificationCenter.default.post(name: name, object: nil)
        #expect(await received == 1)
    }
}
