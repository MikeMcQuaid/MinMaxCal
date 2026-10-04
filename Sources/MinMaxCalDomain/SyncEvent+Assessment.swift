import Foundation

extension SyncEvent {
    func exclusion(for policy: SyncPolicy, in interval: DateInterval) -> SyncAssessment.Outcome? {
        if isCopy {
            return .copy
        }
        if isCancelled {
            return .cancelled
        }
        if response == .declined {
            return .declined
        }
        if response == .pending {
            return .unanswered
        }
        if isAccepted == false, response != nil, response != .tentative {
            return .unaccepted
        }
        if content.end <= interval.start || content.start >= interval.end {
            return .outsideWindow
        }
        let availability = content.availabilityForCopy
        if policy.onlyBusy, availability != .busy {
            return .notBusy
        }
        if content.isAllDay, policy.allDay == .exclude || (policy.allDay == .busy && availability != .busy) {
            return .allDay
        }
        return nil
    }
}
