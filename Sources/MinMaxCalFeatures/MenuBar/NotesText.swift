import MinMaxCalDomain
import SwiftUI

struct NotesText: View {
    // MARK: Lifecycle

    init(_ notes: String) {
        self.notes = notes
    }

    // MARK: Internal

    var body: some View {
        Text(LinkedText.attributed(notes))
            .textSelection(.enabled)
    }

    // MARK: Private

    private let notes: String
}
