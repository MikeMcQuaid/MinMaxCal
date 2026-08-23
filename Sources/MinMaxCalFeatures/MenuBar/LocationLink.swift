import Foundation
import MinMaxCalDomain
import SwiftUI

/// A location as a link: a web address opens itself, anything else is searched in Apple Maps.
struct LocationLink: View {
    // MARK: Lifecycle

    init(_ location: String) {
        self.location = location
    }

    // MARK: Internal

    var body: some View {
        if let destination {
            Link(location, destination: destination)
        } else {
            Text(location)
        }
    }

    // MARK: Private

    private let location: String

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
