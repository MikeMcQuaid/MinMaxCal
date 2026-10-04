import Foundation
import MinMaxCalData
import MinMaxCalDomain
import MinMaxCalFeatures
import Testing

extension CalendarSyncModelTests {
    @Test
    func `rehearsal checks adoption creation and deletion without performing any of them`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        var legacy = Fixtures.syncOriginal
        legacy.identity = SyncIdentity(calendar: "work", item: "legacy", event: "legacy")
        legacy.content.notes = "This event was created by https://app.reclaim.ai/signup?utm_medium=calendar-sync-event"
        var second = Fixtures.syncOriginal
        second.identity = SyncIdentity(calendar: "home", item: "second", event: "second")
        second.content.start = Fixtures.syncOriginal.content.end
        second.content.end = second.content.start.addingTimeInterval(600)
        let removed = SyncLink(
            policy: Fixtures.syncPolicy.id,
            source: SyncIdentity(calendar: "home", item: "gone", event: "gone"),
            destination: "work",
            end: Fixtures.syncOriginal.content.end.addingTimeInterval(3_600),
            copy: SyncIdentity(calendar: "work", item: "orphan", event: "orphan"),
            missingSince: Fixtures.now.addingTimeInterval(-60),
            isManaged: true,
        )
        var orphan = try SyncEvent(
            identity: #require(removed.copy), content: Fixtures.syncOriginal.copyContent(
                for: Fixtures.syncPolicy,
                id: removed.id,
            ),
        )
        orphan.content.start = orphan.content.start.addingTimeInterval(3_600)
        orphan.content.end = removed.end
        let source = FakeCalendarSyncSource(
            events: [Fixtures.syncOriginal, legacy, second, orphan],
            calendars: Fixtures.syncCalendars,
        )
        let ledger = SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json"))
        try ledger.save([removed])
        let model = CalendarSyncModel(source: source, settings: settings, ledger: ledger, clock: Fixtures.clock)
        await model.refresh(rehearsing: true)
        #expect(Set(source.rehearsedActions) == [.adopt, .create, .remove])
        #expect(model.rehearsal?.checked == 3)
        #expect(source.writes == 0)
        #expect(try ledger.load().filter(\.isManaged).map(\.id) == [removed.id])
        let snapshot = await source.syncSnapshot(policies: [Fixtures.syncPolicy], links: [], interval: DateInterval())
        #expect(snapshot.events == [Fixtures.syncOriginal, legacy, second, orphan])
    }

    @Test(arguments: [false, true])
    func `rehearsal reports local failures without writing or claiming ownership`(failing: Bool) async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        var second = Fixtures.syncOriginal
        second.identity = SyncIdentity(calendar: "home", item: "second", event: "second")
        second.content.start = Fixtures.syncOriginal.content.end
        second.content.end = second.content.start.addingTimeInterval(600)
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal, second], calendars: Fixtures.syncCalendars)
        source.rehearsalError = failing ? .changed : nil
        let ledger = SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json"))
        let model = CalendarSyncModel(source: source, settings: settings, ledger: ledger, clock: Fixtures.clock)
        await model.refresh(rehearsing: true)
        #expect(source.rehearsals == 2)
        #expect(source.writes == 0)
        #expect(model.rehearsal?.checked == 2)
        #expect(model.rehearsal?.failures.count == (failing ? 2 : 0))
        #expect(try ledger.load().allSatisfy { $0.isManaged == false && $0.copy == nil })
        await model.refresh()
        #expect(model.rehearsal == nil)
        #expect(model.report.writes.count == 2)
        #expect(source.writes == 0)
    }

    @Test(arguments: [SyncSettings.Mode.off, .sync])
    func `rehearsal only runs in Compare and can never enable live syncing`(mode: SyncSettings.Mode) async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: mode, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh(rehearsing: true)
        #expect(source.fetches == 0)
        #expect(source.writes == 0)
        #expect(source.rehearsals == 0)
        #expect(model.rehearsal == nil)
    }

    @Test
    func `rehearsing an empty calendar reports zero checks`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh(rehearsing: true)
        #expect(model.lastChecked != nil)
        #expect(model.report.checkedPolicies == [Fixtures.syncPolicy.id])
        #expect(model.rehearsal?.checked == 0)
        #expect(source.rehearsals == 0)
        #expect(source.writes == 0)
    }
}
