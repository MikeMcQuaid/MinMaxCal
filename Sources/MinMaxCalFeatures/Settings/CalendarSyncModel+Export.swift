import Foundation

extension CalendarSyncModel {
    func exportDiagnostics() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(SyncDiagnostics(
            exportedAt: clock(),
            timeZone: calendar.timeZone.identifier,
            configuration: configuration,
            ownership: links,
            lastChecked: lastChecked,
            snapshot: diagnosticSnapshot,
            rehearsal: rehearsal.map { result in
                SyncDiagnostics.Rehearsal(
                    checked: result.checked,
                    failures: Dictionary(uniqueKeysWithValues: result.failures.map { ($0.key.uuidString, $0.value) }),
                )
            },
            error: errorMessage,
        ))
    }
}
