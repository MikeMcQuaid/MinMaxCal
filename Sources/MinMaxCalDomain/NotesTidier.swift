import Foundation

/// Removes the boilerplate calendar tools append to invitations: a scheduling assistant's
/// visibility notice always, and a conferencing service's joining details once the join button
/// already carries the link.
public enum NotesTidier {
    /// Whether the notes are a scheduling assistant's, which only echo a block it created.
    public static func isFromSchedulingTool(_ notes: String) -> Bool {
        notes.contains("reclaim.ai") || notes.contains("This time has been blocked on your calendar")
    }

    /// The notes without the rails, headers and notices other tools wrapped around them.
    public static func removingBoilerplate(from notes: String, hasCallLink: Bool) -> String {
        var text = notes
        // Reclaim's notice about the block it created.
        let visibilityNotice =
            /(?:This time has been blocked on your calendar|This description is visible to anyone)[^\n]*\n?/
        text = text.replacing(visibilityNotice, with: "")
        if hasCallLink {
            // Google Calendar wraps Zoom's joining details in `-::~:~::~...::-` rails.
            let zoomRails = /-::~:~::~[:~]*::-[\s\S]*?-::~:~::~[:~]*::-\.?/
            text = text.replacing(zoomRails, with: "")
            // Zoom's own invitation text sits under an `Event Details` banner down to a rule.
            let eventDetails = /~+ ?Event Details ?~+[\s\S]*?(?:\n-{3,}\s*|$)/
            text = text.replacing(eventDetails, with: "")
            // The invitation Zoom itself writes, from the host's name down to the rule.
            let invitation = /[^\n]*is inviting you to a scheduled Zoom meeting\.[\s\S]*?(?:\n-{3,}\s*|$)/
            text = text.replacing(invitation, with: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
