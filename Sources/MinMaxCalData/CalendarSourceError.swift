import Foundation

public enum CalendarSourceError: LocalizedError {
    case reminderNotFound

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .reminderNotFound:
            "The reminder no longer exists in Reminders."
        }
    }
}
