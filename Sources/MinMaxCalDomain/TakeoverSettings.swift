import Foundation

public struct TakeoverSettings: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(onEventStart: Bool, onReminderDue: Bool, snoozeMinutes: [Int], sound: TakeoverSound? = .default) {
        self.onEventStart = onEventStart
        self.onReminderDue = onReminderDue
        self.snoozeMinutes = snoozeMinutes
        self.sound = sound
    }

    /// Settings saved before the sound existed have no key and take the default; none is null.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onEventStart = try container.decode(Bool.self, forKey: .onEventStart)
        onReminderDue = try container.decode(Bool.self, forKey: .onReminderDue)
        snoozeMinutes = try container.decode([Int].self, forKey: .snoozeMinutes)
        sound = try container.contains(.sound) ? container.decode(TakeoverSound?.self, forKey: .sound) : .default
    }

    // MARK: Public

    public static let `default`: Self = .init(
        onEventStart: true,
        onReminderDue: true,
        snoozeMinutes: [shortSnooze, mediumSnooze, longSnooze],
    )
    public static let lookback: TimeInterval = 600

    public var onEventStart: Bool
    public var onReminderDue: Bool
    public var snoozeMinutes: [Int]
    public var sound: TakeoverSound?

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(onEventStart, forKey: .onEventStart)
        try container.encode(onReminderDue, forKey: .onReminderDue)
        try container.encode(snoozeMinutes, forKey: .snoozeMinutes)
        try container.encode(sound, forKey: .sound)
    }

    // MARK: Private

    private enum CodingKeys: CodingKey {
        case onEventStart
        case onReminderDue
        case snoozeMinutes
        case sound
    }

    private static let shortSnooze = 5
    private static let mediumSnooze = 15
    private static let longSnooze = 60
}
