import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct SyncDiagnosticsTests {
    // MARK: Internal

    @Test
    func `export includes hidden events reasons and rehearsal failures without another check`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .compare, policies: [Fixtures.syncPolicy])
        var original = Fixtures.syncOriginal
        original.content.notes = "Private notes with https://example.com/meeting"
        var skipped = original
        skipped.identity.item = "free"
        skipped.content.availability = .free
        var unmatched = original
        unmatched.identity = SyncIdentity(calendar: "work", item: "unmatched", event: "unmatched")
        unmatched.content.start.addTimeInterval(3_600)
        unmatched.content.end.addTimeInterval(3_600)
        unmatched.content.notes = """
        This event was created by https://app.reclaim.ai/signup?utm_medium=calendar-sync-event
        """
        let source = FakeCalendarSyncSource(events: [original, skipped, unmatched], calendars: Fixtures.syncCalendars)
        source.rehearsalError = .changed
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh(rehearsing: true)
        let data = try model.exportDiagnostics()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 1)
        #expect(json["exportedAt"] as? Double == Fixtures.now.timeIntervalSince1970)
        let snapshot = try #require(json["snapshot"] as? [String: Any])
        let plan = try #require(snapshot["plan"] as? [String: Any])
        #expect((snapshot["events"] as? [Any])?.count == 3)
        #expect((snapshot["calendars"] as? [Any])?.count == 2)
        #expect((plan["unresolved"] as? [Any])?.count == 1)
        let counts = try #require(snapshot["counts"] as? [String: Int])
        #expect(counts["Create a new copy"] == 1)
        #expect(counts["No changes"] == 1)
        let writes = try #require(plan["writes"] as? [[String: Any]])
        #expect(writes.first?["action"] as? String == "Create a new copy")
        #expect((writes.first?["reasons"] as? [String])?.isEmpty == false)
        #expect(String(data: data, encoding: .utf8)?.contains(original.content.notes ?? "missing notes") == true)
        let rehearsal = try #require(json["rehearsal"] as? [String: Any])
        #expect(rehearsal["checked"] as? Int == 1)
        #expect((rehearsal["failures"] as? [String: String])?.count == 1)
        #expect(source.fetches == 1)
        #expect(source.rehearsals == 1)
        #expect(source.writes == 0)
    }

    @Test
    func `export preserves planning inputs separately from ownership after a write`() async throws {
        let settings: SettingsStore = try Fixtures.settingsStore()
        settings.sync = SyncSettings(mode: .sync, policies: [Fixtures.syncPolicy])
        let source = FakeCalendarSyncSource(events: [Fixtures.syncOriginal], calendars: Fixtures.syncCalendars)
        let model = CalendarSyncModel(
            source: source,
            settings: settings,
            ledger: SyncLedgerStore(file: Fixtures.scratchDirectory().appending(path: "sync.json")),
            clock: Fixtures.clock,
        )
        await model.refresh()
        let json = try #require(JSONSerialization.jsonObject(with: model.exportDiagnostics()) as? [String: Any])
        let snapshot = try #require(json["snapshot"] as? [String: Any])
        #expect((snapshot["inputLinks"] as? [Any])?.isEmpty == true)
        #expect((snapshot["events"] as? [Any])?.count == 1)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let input = try decoder.decode(Input.self, from: JSONSerialization.data(withJSONObject: snapshot))
        let replay = SyncPlanner(
            events: input.events,
            calendars: input.calendars,
            policies: settings.sync.policies,
            links: input.inputLinks,
            interval: input.interval,
        ).plan()
        #expect(replay.writes.map(\.action) == model.report.writes.map(\.action))
        #expect(input.events == [Fixtures.syncOriginal])
        let ownership = try #require(json["ownership"] as? [[String: Any]])
        #expect(ownership.first?["isManaged"] as? Bool == true)
        #expect(ownership.first?["copy"] != nil)
        #expect(source.fetches == 1)
        #expect(source.writes == 1)
        model.configuration.mode = .off
        let cleared = try #require(JSONSerialization.jsonObject(with: model.exportDiagnostics()) as? [String: Any])
        #expect(cleared["snapshot"] == nil)
        #expect(cleared["lastChecked"] == nil)
        #expect(cleared["rehearsal"] == nil)
    }

    @Test
    func `export remains available for errors without a calendar snapshot`() throws {
        let file = Fixtures.scratchDirectory().appending(path: "sync.json")
        try Data("broken".utf8).write(to: file)
        let source = FakeCalendarSyncSource(events: [], calendars: [])
        let model = try CalendarSyncModel(
            source: source,
            settings: Fixtures.settingsStore(),
            ledger: SyncLedgerStore(file: file),
            clock: Fixtures.clock,
        )
        let json = try #require(JSONSerialization.jsonObject(with: model.exportDiagnostics()) as? [String: Any])
        #expect(json["error"] as? String == model.errorMessage)
        #expect(json["error"] != nil)
        #expect(json["snapshot"] == nil)
        #expect(json["configuration"] != nil)
        #expect(source.fetches == 0)
        #expect(source.writes == 0)
    }

    @Test
    func `the native exporter saves the JSON bytes as a JSON file`() async throws {
        let data = Data("{\"schemaVersion\":1}".utf8)
        let document = SyncReportDocument(data: data)
        let file = try await document.export(to: Fixtures.scratchDirectory(), contentType: .json)
        #expect(file.pathExtension == "json")
        #expect(try Data(contentsOf: file) == data)
    }

    // MARK: Private

    private struct Input: Decodable {
        let interval: DateInterval
        let calendars: [CalendarList]
        let events: [SyncEvent]
        let inputLinks: [SyncLink]
    }
}
