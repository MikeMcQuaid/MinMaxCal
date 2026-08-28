import Foundation

/// Finds the call link in an item's URL, location and notes and decides where it opens.
public enum JoinLinkDetector {
    // MARK: Public

    /// The first recognised call link in field order, or failing that the event's own URL when it
    /// is a web address; a plain link in the location or notes is never a call.
    public static func detect(url: URL?, location: String?, notes: String?, rules: MatchingRules) -> JoinLink? {
        let candidates = [url].compactMap(\.self) + links(in: location ?? "").map(\.url) + links(in: notes ?? "")
            .map(\.url)
        let recognised = candidates.compactMap { classify($0, rules: rules) }
        return recognised.first { $0.service != .other } ?? url.flatMap { classify($0, rules: rules) }
    }

    /// Every web and `zoommtg://` link in the text with its range, for rendering notes.
    public static func links(in text: String) -> [TextLink] {
        let zoomLinks = text.matches(of: /zoommtg:\/\/\S+/).compactMap { match in
            URL(string: String(match.output)).map { TextLink(range: match.range, url: $0) }
        }
        guard let detector else {
            return zoomLinks
        }

        let webLinks = detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let url = match.url, let range = Range(match.range, in: text),
                  webSchemes.contains(url.scheme?.lowercased() ?? "")
            else {
                return nil as TextLink?
            }

            return TextLink(range: range, url: url)
        }
        return (zoomLinks + webLinks).sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Turns one URL into a `JoinLink`, or nil for schemes that must never be opened.
    public static func classify(_ url: URL, rules: MatchingRules) -> JoinLink? {
        guard let scheme = url.scheme?.lowercased(), let host = url.host()?.lowercased() else {
            return nil
        }

        if scheme == zoomScheme {
            return zoomLink(from: url, host: host)
        }
        guard webSchemes.contains(scheme) else {
            return nil
        }

        if isZoomHost(host), let link = zoomMeetingLink(from: url) {
            return link
        }
        if host == meetHost {
            return JoinLink(service: .meet, url: secured(url))
        }
        if rules.isJitsiHost(host) {
            return JoinLink(service: .jitsi, url: secured(url))
        }
        return JoinLink(service: .other, url: url)
    }

    // MARK: Private

    private static let webSchemes: Set<String> = ["http", "https"]
    /// Built once: a detector compiles its grammar on creation, and every event's fields pass through here.
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let zoomScheme = "zoommtg"
    private static let zoomHost = "zoom.us"
    private static let meetHost = "meet.google.com"
    private static let passcodeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))

    private static func isZoomHost(_ host: String) -> Bool {
        host == zoomHost || host.hasSuffix(".\(zoomHost)")
    }

    private static func zoomMeetingLink(from url: URL) -> JoinLink? {
        let components = url.pathComponents.dropFirst()
        guard components.first == "j", let meetingID = components.dropFirst().first else {
            return nil
        }

        return zoomLink(meetingID: meetingID, passcode: queryValue("pwd", in: url))
    }

    private static func zoomLink(from url: URL, host: String) -> JoinLink? {
        guard isZoomHost(host), let meetingID = queryValue("confno", in: url) else {
            return nil
        }

        return zoomLink(meetingID: meetingID, passcode: queryValue("pwd", in: url))
    }

    private static func zoomLink(meetingID: String, passcode: String?) -> JoinLink? {
        guard meetingID.isEmpty == false, meetingID.allSatisfy(\.isNumber) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = zoomScheme
        components.host = zoomHost
        components.path = "/join"
        components.queryItems = [URLQueryItem(name: "confno", value: meetingID)]
        if let passcode, passcode.isEmpty == false, passcode.unicodeScalars.allSatisfy(passcodeCharacters.contains) {
            components.queryItems?.append(URLQueryItem(name: "pwd", value: passcode))
        }
        return components.url.map { JoinLink(service: .zoom, url: $0) }
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    private static func secured(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.scheme = "https"
        return components.url ?? url
    }
}
