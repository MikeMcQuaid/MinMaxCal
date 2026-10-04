import Foundation

public enum SyncError: LocalizedError {
    case access
    case calendar
    case changed
    case ownership

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case .access:
            "Calendar sync needs full calendar access."

        case .calendar:
            "A calendar is missing, read-only or does not support availability."

        case .changed:
            "An event changed during sync. It will be checked again on the next refresh."

        case .ownership:
            "The event cannot be verified as a managed copy."
        }
    }
}
