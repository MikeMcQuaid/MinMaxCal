import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Observation
import Synchronization
import Testing

struct AgendaRefreshTests {
    // MARK: Lifecycle

    init() throws {
        store = try Fixtures.settingsStore()
        model = AgendaModel(source: source, settings: store, opener: FakeLinkOpener(), clock: clock.read)
    }

    // MARK: Internal

    @Test
    func `a minute updates the countdown without fetching or replanning a takeover`() async {
        source.items = [Fixtures.event("event", startingIn: 30)]
        await model.rebuild()
        var replanned = false
        model.onRebuild = { _, _ in replanned = true }

        clock.now = Fixtures.now.addingTimeInterval(60)
        await model.tick()

        #expect(model.title == "Event 29m")
        #expect(source.fetches == 1)
        #expect(replanned == false)
    }

    @Test
    func `a minute removes ended events without fetching`() async {
        source.items = [Fixtures.event("ending", startingIn: -29), Fixtures.event("next", startingIn: 30)]
        await model.rebuild()

        clock.now = Fixtures.now.addingTimeInterval(60)
        await model.tick()

        #expect(model.agenda.items.map(\.id) == [source.items[1].id])
        #expect(source.fetches == 1)
    }

    @Test
    func `an overdue reminder leaves the title without fetching`() async {
        source.items = [Fixtures.reminder("overdue", dueIn: -59), Fixtures.event("next", startingIn: 30)]
        await model.rebuild()

        clock.now = Fixtures.now.addingTimeInterval(2 * 60)
        await model.tick()

        #expect(model.title == "Event 28m")
        #expect(model.agenda.items.count == 2)
        #expect(source.fetches == 1)
    }

    @Test
    func `an unchanged title does not invalidate its view`() async {
        source.items = [Fixtures.reminder("overdue", dueIn: -10)]
        await model.rebuild()
        let changed = Mutex(false)
        withObservationTracking {
            _ = model.title
        } onChange: {
            changed.withLock { $0 = true }
        }

        clock.now = Fixtures.now.addingTimeInterval(60)
        await model.tick()

        #expect(changed.withLock { $0 } == false)
    }

    @Test
    func `the mains fallback fetches after five minutes`() async {
        await model.rebuild()
        source.items = [Fixtures.event("new")]

        clock.now = Fixtures.now.addingTimeInterval(4 * 60)
        await model.tick()
        #expect(source.fetches == 1)

        clock.now = Fixtures.now.addingTimeInterval(5 * 60)
        await model.tick()
        #expect(source.fetches == 2)
        #expect(model.agenda.items == source.items)
    }

    @Test
    func `battery refreshes every fifteen minutes while countdowns stay current`() async {
        source.items = [Fixtures.event("event", startingIn: 30)]
        model.setPowerSaving(true)
        await model.rebuild()

        for minute in 1 ..< 15 {
            clock.now = Fixtures.now.addingTimeInterval(Double(minute) * 60)
            await model.tick()
            #expect(source.fetches == 1)
            #expect(model.title == "Event \(30 - minute)m")
        }

        clock.now = Fixtures.now.addingTimeInterval(15 * 60)
        await model.tick()
        #expect(source.fetches == 2)
    }

    @Test
    func `empty agendas skip minute wakes and power changes move the fallback`() async {
        await model.rebuild()
        #expect(model.nextTick == Fixtures.now.addingTimeInterval(5 * 60))

        model.setPowerSaving(true)
        #expect(model.nextTick == Fixtures.now.addingTimeInterval(15 * 60))
        #expect(source.fetches == 1)

        model.setPowerSaving(false)
        #expect(model.nextTick == Fixtures.now.addingTimeInterval(5 * 60))
        #expect(source.fetches == 1)
    }

    @Test
    func `a populated agenda still wakes on minute boundaries on battery`() async {
        source.items = [Fixtures.event("event")]
        model.setPowerSaving(true)
        await model.rebuild()

        #expect(model.nextTick == Fixtures.now.addingTimeInterval(60))
    }

    @Test
    func `completed rows expire locally on battery and the title updates on undo`() async {
        let reminder = Fixtures.reminder("reminder")
        source.items = [reminder]
        model.setPowerSaving(true)
        await model.rebuild()
        await model.complete(reminder)
        #expect(model.title == nil)

        await model.uncomplete(reminder)
        #expect(model.title == "Reminder 30m")
        await model.complete(reminder)
        source.items = []

        clock.now = Fixtures.now.addingTimeInterval(6 * 60)
        await model.tick()

        #expect(model.agenda.items.isEmpty)
        #expect(source.fetches == 1)
        #expect(model.nextTick == Fixtures.now.addingTimeInterval(15 * 60))
    }

    @Test
    func `a clock change backwards forces a fresh agenda`() async {
        await model.rebuild()
        source.items = [Fixtures.event("event")]
        clock.now = Fixtures.now.addingTimeInterval(-60)

        await model.tick()

        #expect(source.fetches == 2)
        #expect(model.agenda.items == source.items)
    }

    @Test
    func `an empty selection never fetches EventKit`() async {
        store.selection = .empty
        await model.rebuild()
        #expect(source.fetches == 0)
    }

    @Test
    func `midnight refreshes the horizon even when the battery fallback is not due`() async throws {
        let tomorrow = try #require(Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: Fixtures.now),
        ))

        clock.now = tomorrow.addingTimeInterval(-60)
        model.setPowerSaving(true)
        await model.rebuild()

        clock.now = tomorrow
        await model.tick()

        #expect(source.fetches == 2)
        #expect(model.agenda.horizon.start == tomorrow)
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let clock: AdjustableClock = .init()
    private let store: SettingsStore
    private let model: AgendaModel
}
