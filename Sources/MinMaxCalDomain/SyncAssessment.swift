import Foundation

/// Explains one source event's contribution to a calendar pair's plan.
public struct SyncAssessment: Encodable, Sendable {
    public enum Outcome: String, Encodable, CaseIterable, Sendable {
        case create = "Needs a new copy"
        case adopt = "Existing copy found"
        case update = "Copy needs updating"
        case unchanged = "Copy already up to date"
        case invitation = "Invitation already in destination"
        case shared = "Handled by another enabled pair"
        case waiting = "Waiting for missing-event confirmation"
        case blocked = "Needs review before copying"
        case copy = "The source event is itself a copy."
        case cancelled = "The original event was cancelled."
        case declined = "You declined the original invitation."
        case unanswered = "You have not answered the original invitation."
        case unaccepted = "The original invitation is not accepted."
        case notBusy = "The original is marked Free, Tentative or Unavailable; this pair only copies Busy events."
        case allDay = "The original no longer matches this pair’s all-day settings."
        case outsideWindow = "The original is outside the maintained month."

        // MARK: Public

        public var isEligible: Bool {
            switch self {
            case .adopt,
                 .blocked,
                 .create,
                 .invitation,
                 .shared,
                 .unchanged,
                 .update,
                 .waiting:
                true

            default:
                false
            }
        }
    }

    public let policy: UUID
    public let event: SyncEvent
    public let outcome: Outcome
}
