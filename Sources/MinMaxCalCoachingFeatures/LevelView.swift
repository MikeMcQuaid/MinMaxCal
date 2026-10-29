import SwiftUI

struct LevelView: View {
    let title: String
    let level: Float

    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            ProgressView(value: level).tint(.teal).accessibilityLabel(title)
        }
    }
}
