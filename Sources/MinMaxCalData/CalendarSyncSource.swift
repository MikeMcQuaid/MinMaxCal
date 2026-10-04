import Foundation
import MinMaxCalDomain

public protocol CalendarSyncSource: Sendable {
    func syncSnapshot(
        policies: [SyncPolicy], links: [SyncLink], interval: DateInterval,
    ) async throws -> (calendars: [CalendarList], events: [SyncEvent])
    func applySync(_ write: SyncWrite) async throws -> SyncIdentity?
    func rehearseSync(_ write: SyncWrite) async throws
    func removeLegacyCopy(_ event: SyncEvent, interval: DateInterval) async throws
}
