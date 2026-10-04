import Foundation
import MinMaxCalData
import MinMaxCalDomain
import MinMaxCalFeatures
import Testing

struct SyncRemovalTests {
    @Test
    func `removal preview counts owned copies and confirmation removes only the reviewed set`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let ledger = SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json"))
        let model = CalendarSyncModel(source: source, settings: settings, ledger: ledger, clock: Fixtures.clock)
        await model.refresh()
        let preview = try await model.removalPreview(for: Fixtures.syncPolicy.id)
        #expect(preview.count == 1)
        #expect(preview.first?.action == .remove)
        #expect(model.configuration.policies.first?.isEnabled == true)
        #expect(source.writes == 1)
        let extra = SyncLink(
            policy: Fixtures.syncPolicy.id,
            source: Fixtures.syncOriginal.identity,
            destination: "work",
            end: Fixtures.syncOriginal.content.end,
            isManaged: true,
        )
        _ = try source.applySync(.save(
            extra,
            source: Fixtures.syncOriginal,
            target: nil,
            content: Fixtures.syncOriginal.copyContent(for: Fixtures.syncPolicy, id: extra.id),
        ))
        await model.removeCopies(preview, for: Fixtures.syncPolicy.id)
        #expect(source.writes == 3)
        #expect(model.configuration.policies.first?.isEnabled == false)
        #expect(model.links.isEmpty)
        let remaining = await source.syncSnapshot(policies: [], links: [], interval: DateInterval())
        #expect(remaining.events.count == 2)
        #expect(remaining.events.contains { SyncMarker.identifier(in: $0.content.notes) == extra.id })
    }
}
