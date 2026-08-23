import Foundation

/// Removes the boilerplate a conferencing service appends to an invitation once the join button
/// already carries its link.
public enum NotesTidier {
    /// The notes without the rails a calendar service wrapped the joining details in.
    public static func removingCallBoilerplate(from notes: String) -> String {
        var text = notes
        // Google Calendar wraps Zoom's joining details in `-::~:~::~...::-` rails.
        let zoomBlock = /-::~:~::~[:~]*::-[\s\S]*?-::~:~::~[:~]*::-\.?/
        while let block = text.firstRange(of: zoomBlock) {
            text.removeSubrange(block)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
