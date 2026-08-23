public struct ListColour: Hashable, Sendable {
    // MARK: Lifecycle

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    // MARK: Public

    public static let grey: Self = .init(red: midGrey, green: midGrey, blue: midGrey)
    // swiftlint:disable no_magic_numbers - the sRGB components of the sample palette
    public static let blue: Self = .init(red: 0.2, green: 0.45, blue: 0.9)
    public static let orange: Self = .init(red: 0.9, green: 0.5, blue: 0.15)
    public static let red: Self = .init(red: 0.85, green: 0.25, blue: 0.3)

    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    // MARK: Private

    // swiftlint:enable no_magic_numbers

    private static let midGrey = 0.5
}
