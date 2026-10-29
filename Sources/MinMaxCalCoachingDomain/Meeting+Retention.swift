import Foundation

public extension Meeting {
    /// The time all saved meeting data expires, including meetings without transcripts.
    func expiry(retention: MeetingRetention) -> Date {
        (endedAt ?? startedAt.addingTimeInterval(duration)).addingTimeInterval(retention.duration)
    }

    /// Whether the complete saved meeting is due for deletion.
    func hasExpired(retention: MeetingRetention, at date: Date) -> Bool {
        expiry(retention: retention) <= date
    }
}
