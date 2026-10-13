import SwiftUI

public struct AboutLinks: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        link("Source", "github.com/MikeMcQuaid/MinMaxCal", to: "https://github.com/MikeMcQuaid/MinMaxCal")
        link("Licence", "AGPL-3.0", to: "https://github.com/MikeMcQuaid/MinMaxCal/blob/main/LICENSE")
    }

    // MARK: Private

    @ViewBuilder
    private func link(_ label: String, _ title: String, to address: String) -> some View {
        if let url = URL(string: address) {
            LabeledContent(label) {
                Link(title, destination: url)
            }
        }
    }
}
