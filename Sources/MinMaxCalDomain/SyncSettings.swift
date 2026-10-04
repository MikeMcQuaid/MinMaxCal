public struct SyncSettings: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(mode: Mode = .off, policies: [SyncPolicy] = []) {
        self.mode = mode
        self.policies = policies
    }

    // MARK: Public

    public enum Mode: String, Codable, CaseIterable, Sendable {
        case off
        case compare
        case sync
    }

    public var mode: Mode
    public var policies: [SyncPolicy]
}
