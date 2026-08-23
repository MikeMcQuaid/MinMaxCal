import Foundation

public struct TakeoverSettings: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(onEventStart: Bool, onReminderDue: Bool, snoozeMinutes: [Int]) {
        self.onEventStart = onEventStart
        self.onReminderDue = onReminderDue
        self.snoozeMinutes = snoozeMinutes
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

    // MARK: Private

    private static let shortSnooze = 5
    private static let mediumSnooze = 15
    private static let longSnooze = 60
}
