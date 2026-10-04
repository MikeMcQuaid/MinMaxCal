import Foundation

public struct SyncIdentity: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(
        calendar: String,
        item: String,
        event: String,
        external: String? = nil,
        occurrence: Date? = nil,
    ) {
        self.calendar = calendar
        self.item = item
        self.event = event
        self.external = external
        self.occurrence = occurrence
    }

    // MARK: Public

    public var calendar: String
    public var item: String
    public var event: String
    public var external: String?
    public var occurrence: Date?

    public func matches(_ other: Self) -> Bool {
        calendar == other.calendar && occurrence == other.occurrence
            && (item == other.item || (external != nil && external == other.external))
    }
}
