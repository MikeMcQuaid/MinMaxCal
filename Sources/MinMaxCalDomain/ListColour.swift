import Foundation

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

    // swiftlint:enable no_magic_numbers

    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    /// The colour tuned for a small solid tile: its brightness pulled into a band where it stands
    /// out and a white glyph still reads on it, then a touch more saturated. Scaling every
    /// component alike, and stretching each the same way from the new peak, keeps the hue.
    public var vivid: Self {
        let brightest = max(red, green, blue, Double.ulpOfOne)
        let target = min(max(brightest, Self.brightnessBand.lowerBound), Self.brightnessBand.upperBound)
        let scale = target / brightest
        func tuned(_ component: Double) -> Double {
            max(0, target - (target - component * scale) * Self.extraSaturation)
        }
        return Self(red: tuned(red), green: tuned(green), blue: tuned(blue), alpha: alpha)
    }

    // MARK: Private

    private static let midGrey = 0.5
    private static let extraSaturation = 1.15
    private static let brightnessBand = 0.72 ... 0.85
}
