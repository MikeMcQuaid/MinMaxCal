import Foundation
import MinMaxCalDomain
import SwiftUI

struct NotesText: View {
    // MARK: Lifecycle

    init(_ notes: String) {
        self.notes = notes
    }

    // MARK: Internal

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
    }

    // MARK: Private

    private let notes: String

    private var attributed: AttributedString {
        var result = AttributedString(notes)
        for link in JoinLinkDetector.links(in: notes) where link.url.scheme != "zoommtg" {
            guard let range = Range(link.range, in: result) else {
                continue
            }

            result[range].link = link.url
        }
        return result
    }
}
