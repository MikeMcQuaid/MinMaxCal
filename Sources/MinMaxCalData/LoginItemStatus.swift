public enum LoginItemStatus: Hashable, Sendable {
    case enabled
    case notFound
    case notRegistered
    case requiresApproval

    // MARK: Public

    public var isEnabled: Bool {
        self == .enabled
    }
}
