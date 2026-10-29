import Foundation

/// Keeps model-local speaker slots distinct across hourly resets.
public enum SpeakerIdentity {
    /// Adds an hourly scope without changing first-hour identities in older history.
    public static func scoped(_ identifier: String, session: Int) -> String {
        if session == 0 {
            identifier
        } else {
            "\(identifier)@\(session)"
        }
    }

    /// Collapses remote slots for a one-to-one while preserving their hourly scope.
    public static func oneToOne(_ identifier: String) -> String {
        guard identifier.hasPrefix("speaker-") else {
            return identifier
        }

        return "speaker-1" + (identifier.firstIndex(of: "@").map { String(identifier[$0...]) } ?? "")
    }

    /// Displays fresh labels without implying identity across model resets.
    public static func title(for identifier: String) -> String {
        let parts = identifier.split(separator: "@", maxSplits: 1)
        let name = String(parts.first ?? "").replacing("speaker-", with: "Speaker ")
        if let session = parts.dropFirst().first.flatMap({ Int($0) }), session > 0, session < Int.max {
            return "\(name) (hour \(session + 1))"
        }
        return name
    }
}
