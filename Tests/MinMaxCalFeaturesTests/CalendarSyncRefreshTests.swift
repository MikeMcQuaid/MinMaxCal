import Foundation
import MinMaxCalData
import MinMaxCalDomain
import MinMaxCalFeatures
import Synchronization
import Testing

struct CalendarSyncRefreshTests {
    @Test
    func `checking again keeps the completed report visible while fetching`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        let fetches = Mutex(0)
        let (started, signal) = AsyncStream<Void>.makeStream()
        let (release, gate) = AsyncStream<Void>.makeStream()
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars) {
            let count = fetches.withLock { value in
                value += 1
                return value
            }
            if count > 1 {
                signal.yield()
                for await _ in release {
                    break
                }
            }
        }
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh()
        let checked = model.lastChecked
        let writes = model.report.writes.map(\.link.id)
        let refresh = Task { await model.refresh() }
        var iterator = started.makeAsyncIterator()
        await iterator.next()
        #expect(model.isRunning)
        #expect(model.lastChecked == checked)
        #expect(model.report.writes.map(\.link.id) == writes)
        gate.finish()
        await refresh.value
        signal.finish()
        #expect(model.isRunning == false)
    }
}
