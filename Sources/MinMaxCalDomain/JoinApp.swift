public enum JoinApp: Hashable, Sendable {
    case browser
    case edge
    case zoom

    // MARK: Public

    public var bundleIdentifier: String? {
        switch self {
        case .browser:
            nil

        case .edge:
            "com.microsoft.edgemac"

        case .zoom:
            "us.zoom.xos"
        }
    }
}
