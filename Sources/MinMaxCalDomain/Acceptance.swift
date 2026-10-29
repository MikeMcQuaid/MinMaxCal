/// The rule for whether the user is going to an event.
public enum Acceptance {
    /// Accepts the user's RSVP, own events and shared events without a current-user RSVP.
    public static func isAccepted(organiser: Attendee?, attendees: [Attendee]) -> Bool {
        if organiser?.isCurrentUser == true {
            return true
        }
        return attendees.first(where: \.isCurrentUser).map { $0.response == .accepted } ?? true
    }
}
