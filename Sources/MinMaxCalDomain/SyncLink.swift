import Foundation

public struct SyncLink: Codable, Equatable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        policy: UUID,
        source: SyncIdentity,
        destination: String,
        end: Date,
        id: UUID = UUID(),
        copy: SyncIdentity? = nil,
        missingSince: Date? = nil,
        isManaged: Bool = false,
    ) {
        self.id = id
        self.policy = policy
        self.source = source
        self.destination = destination
        self.copy = copy
        self.end = end
        self.missingSince = missingSince
        self.isManaged = isManaged
    }

    // MARK: Public

    public var id: UUID
    public var policy: UUID
    public var source: SyncIdentity
    public var destination: String
    public var copy: SyncIdentity?
    public var end: Date
    public var missingSince: Date?
    public var isManaged: Bool
}
