import Foundation

extension JoinLinkDetector {
    // MARK: Internal

    /// Both the web address and the `msteams://` deep link for a Teams meeting, each built afresh
    /// from the link's path and the parts of its query the meeting needs: the classic
    /// `/l/meetup-join/<thread>/<n>?context=<json>` or the short `/meet/<id>?p=<passcode>`.
    static func teamsLink(from url: URL, host: String) -> JoinLink? {
        let components = Array(url.pathComponents.dropFirst())
        let query: [URLQueryItem]
        if isClassicMeeting(components) {
            query = [queryValue("context", in: url).flatMap(jsonContext)].compactMap(\.self)
        } else if isShortMeeting(components) {
            query = [queryValue("p", in: url).flatMap(passcode)].compactMap(\.self)
        } else {
            return nil
        }

        var web = URLComponents()
        web.scheme = "https"
        web.host = host
        web.path = "/" + components.joined(separator: "/")
        web.queryItems = query.isEmpty ? nil : query
        var app = web
        app.scheme = teamsScheme
        guard let webURL = web.url, let appURL = app.url else {
            return nil
        }

        return JoinLink(service: .teams, url: webURL, appURL: appURL)
    }

    // MARK: Private

    private static let teamsScheme = "msteams"
    private static let classicPrefixes = ["l", "meetup-join"]
    private static let shortPrefix = "meet"
    /// A thread and its ordinal, or the short form's prefix and meeting id.
    private static let meetingComponentCount = 2
    private static let threadCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ":@._-"))
    private static let meetingCharacters: CharacterSet = .alphanumerics

    /// `/l/meetup-join/<thread>/<n>`.
    private static func isClassicMeeting(_ components: [String]) -> Bool {
        let meeting = components.dropFirst(classicPrefixes.count)
        guard components.starts(with: classicPrefixes), meeting.count == meetingComponentCount,
              let thread = meeting.first, let ordinal = meeting.last
        else {
            return false
        }

        return thread.unicodeScalars.allSatisfy(threadCharacters.contains) && ordinal.allSatisfy(\.isNumber)
    }

    /// `/meet/<id>`.
    private static func isShortMeeting(_ components: [String]) -> Bool {
        guard components.first == shortPrefix, components.count == meetingComponentCount,
              let meetingID = components.last
        else {
            return false
        }

        return meetingID.unicodeScalars.allSatisfy(meetingCharacters.contains)
    }

    private static func jsonContext(_ context: String) -> URLQueryItem? {
        guard let data = context.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
        else {
            return nil
        }

        return URLQueryItem(name: "context", value: context)
    }

    private static func passcode(_ passcode: String) -> URLQueryItem? {
        guard passcode.isEmpty == false, passcode.unicodeScalars.allSatisfy(passcodeCharacters.contains) else {
            return nil
        }

        return URLQueryItem(name: "p", value: passcode)
    }
}
