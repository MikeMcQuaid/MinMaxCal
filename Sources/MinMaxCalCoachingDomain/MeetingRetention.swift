import Foundation

/// The lifetime of all saved meeting data after a recording ends.
public enum MeetingRetention: Int, Sendable {
    /// Keep the meeting for one week.
    case oneWeek = 168
    /// The maximum thirty-day retention.
    case thirtyDays = 720
    /// The default two-day retention.
    case twoDays = 48

    // MARK: Public

    /// The interval in seconds, limited to thirty days.
    public var duration: TimeInterval {
        // swiftlint:disable:next no_magic_numbers - Hours to seconds.
        TimeInterval(rawValue) * 3_600
    }

    /// The title shown in the retention picker.
    public var title: String {
        switch self {
        case .twoDays:
            "48 Hours"

        case .oneWeek:
            "7 Days"

        case .thirtyDays:
            "30 Days"
        }
    }
}
