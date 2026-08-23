import Foundation
import MinMaxCalDomain
import SwiftUI

/// A location as linked text: a web address opens itself, anything else is searched in Apple Maps.
/// The text shown drops the home terms from the rules; the search keeps the full location.
struct LocationLink: View {
    // MARK: Lifecycle

    init(_ location: String, rules: MatchingRules) {
        self.location = location
        self.rules = rules
    }

    // MARK: Internal

    var body: some View {
        Text(linked)
    }

    // MARK: Private

    private let location: String
    private let rules: MatchingRules

    private var linked: AttributedString {
        var text = AttributedString(LocationTidier.display(location, rules: rules))
        text.link = destination
        return text
    }

    private var destination: URL? {
        if let link = JoinLinkDetector.links(in: location).first(where: { $0.url.scheme != "zoommtg" }) {
            return link.url
        }
        var components = URLComponents()
        components.scheme = "maps"
        components.queryItems = [URLQueryItem(name: "q", value: location)]
        return components.url
    }
}
