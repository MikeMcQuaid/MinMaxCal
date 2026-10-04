import Foundation
import MinMaxCalData
import MinMaxCalDomain
import MinMaxCalFeatures
import Testing

struct CalendarSyncModelTests {
    @Test
    func `changing pairs clears the old comparison immediately`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh()
        #expect(model.lastChecked != nil)
        #expect(model.report.writes.isEmpty == false)
        model.configuration.policies.removeAll()
        #expect(model.lastChecked == nil)
        #expect(model.report.writes.isEmpty)
        await model.refresh()
        #expect(model.lastChecked == nil)
        #expect(source.fetches == 1)
    }

    @Test
    func `off does not fetch and comparison never writes even after identifying legacy copies`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh()
        #expect(source.fetches == 0)
        model.configuration = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        await model.refresh()
        #expect(source.fetches > 0)
        #expect(source.writes == 0)
        #expect(model.report.writes.count == 1)
        #expect(model.links.allSatisfy { $0.isManaged == false })
        #expect(model.lastChecked == Fixtures.now)
    }

    @Test
    func `sync persists ownership and a relaunch does not duplicate copies`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let file = Fixtures.scratchDirectory().appending(path: "sync.json")
        let first = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: file),
            clock: Fixtures.clock,
        )
        await first.refresh()
        #expect(source.writes == 1)
        #expect(try SyncLedgerStore(file: file).load().first?.copy != nil)
        #expect(first.links.first?.isManaged == true)
        let second = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: file),
            clock: Fixtures.clock,
        )
        await second.refresh()
        #expect(source.writes == 1)
        #expect(second.report.writes.isEmpty)
    }

    @Test
    func `a corrupt ledger blocks writes instead of discarding ownership`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let file = Fixtures.scratchDirectory().appending(path: "sync.json")
        try Data("broken".utf8).write(to: file)
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: file),
            clock: Fixtures.clock,
        )
        await model.refresh()
        #expect(model.errorMessage != nil)
        #expect(source.writes == 0)
    }

    @Test
    func `removing a pair leaves later copies and preserves their ownership`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let ledger = SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json"))
        let identity = SyncIdentity(calendar: "work", item: "later", event: "later")
        let link = SyncLink(
            policy: Fixtures.syncPolicy.id,
            source: Fixtures.syncOriginal.identity,
            destination: "work",
            end: Fixtures.now.addingTimeInterval(90 * 86_400),
            copy: identity,
            isManaged: true,
        )
        var later = Fixtures.syncOriginal.copyContent(for: Fixtures.syncPolicy, id: link.id)
        later.start = Fixtures.now.addingTimeInterval(60 * 86_400)
        later.end = link.end
        try ledger.save([link])
        let source = FakeCalendarSyncSource(
            events: [SyncEvent(identity: identity, content: later)],
            calendars: Fixtures.syncCalendars,
        )
        let model = CalendarSyncModel(source: source, settings: settings, ledger: ledger, clock: Fixtures.clock)
        let preview = try await model.removalPreview(for: Fixtures.syncPolicy.id)
        #expect(preview.isEmpty)
        await model.removeCopies(preview, for: Fixtures.syncPolicy.id)
        #expect(source.writes == 0)
        #expect(model.links == [link])
        #expect(model.configuration.policies.first?.isEnabled == false)
    }

    @Test
    func `a mode change during a snapshot prevents writes`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let (started, signal) = AsyncStream<Void>.makeStream()
        let (release, gate) = AsyncStream<Void>.makeStream()
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars) {
            signal.yield()
            for await _ in release {
                break
            }
        }
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        let refresh = Task { await model.refresh() }
        var iterator = started.makeAsyncIterator()
        await iterator.next()
        model.configuration.mode = .compare
        gate.finish()
        await refresh.value
        signal.finish()
        #expect(source.writes == 0)
    }

    @Test
    func `a saved copy is recovered if its identifier was never persisted`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        source.failAfterSave = true
        let ledger = SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json"))
        let model = CalendarSyncModel(source: source, settings: settings, ledger: ledger, clock: Fixtures.clock)
        await model.refresh()
        #expect(model.errorMessage != nil)
        #expect(try ledger.load().first?.copy == nil)
        #expect(try ledger.load().first?.isManaged == true)
        source.failAfterSave = false
        await model.refresh()
        #expect(model.errorMessage == nil)
        #expect(try ledger.load().first?.copy != nil)
        #expect(source.writes == 1)
    }

    @Test
    func `an unwritable ledger prevents any calendar mutation`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let parent = Fixtures.scratchDirectory().appending(path: "not-a-directory")
        try Data().write(to: parent)
        let ledger = SyncLedgerStore(file: parent.appending(path: "sync.json"))
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(source: source, settings: settings, ledger: ledger, clock: Fixtures.clock)
        await model.refresh()
        #expect(model.errorMessage != nil)
        #expect(source.writes == 0)
    }
}
