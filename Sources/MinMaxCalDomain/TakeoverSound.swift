/// An alert sound by the name `NSSound` resolves in the user's, the Mac's and the system's Sounds
/// folders.
public struct TakeoverSound: RawRepresentable, Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: Public

    public static let `default`: Self = .init(rawValue: "Glass")

    public let rawValue: String
}
