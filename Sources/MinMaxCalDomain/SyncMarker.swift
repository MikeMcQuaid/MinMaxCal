import Foundation

/// Recognises copy provenance without exposing source identities.
public enum SyncMarker {
    // MARK: Public

    /// The opaque tracking footer written to each managed copy.
    public static func footer(_ id: UUID) -> String {
        "MinMaxCal sync: \(id.uuidString)"
    }

    /// Returns a unique, well-formed tracking UUID from plain text or HTML notes.
    public static func identifier(in notes: String?) -> UUID? {
        guard let notes else {
            return nil
        }

        let identifiers = Set(notes.components(separatedBy: prefix).dropFirst().compactMap { suffix in
            UUID(uuidString: String(suffix.prefix(identifierLength)))
        })
        return identifiers.count == 1 ? identifiers.first : nil
    }

    /// Excludes even malformed tracking notes from source events.
    public static func containsMarker(_ notes: String?) -> Bool {
        notes?.contains(prefix) == true
    }

    /// Recognises the Calendar Sync marker, excluding other scheduling features.
    public static func isLegacy(_ notes: String?) -> Bool {
        guard let notes, notes.contains("This event was created by") else {
            return false
        }

        let text = notes.replacing("&amp;", with: "&")
        return detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)).contains { match in
            guard let url = match.url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return false
            }

            return parts.scheme == "https" && parts.host == "app.reclaim.ai" && parts.path == "/signup"
                && parts.queryItems?.contains(URLQueryItem(name: "utm_medium", value: "calendar-sync-event")) == true
        } == true
    }

    // MARK: Private

    private static let prefix = "MinMaxCal sync: "
    private static let identifierLength = 36
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
}
