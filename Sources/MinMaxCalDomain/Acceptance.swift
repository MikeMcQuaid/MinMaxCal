/// The rule for whether the user is going to an event.
public enum Acceptance {
    /// True for the user's own events, events the user organises and invitations the user accepted.
    public static func isAccepted(organiser: Attendee?, attendees: [Attendee]) -> Bool {
        if attendees.isEmpty || organiser?.isCurrentUser == true {
            return true
        }
        return attendees.contains { $0.isCurrentUser && $0.response == .accepted }
    }
}
