import SwiftUI

public struct MenuBarLabel: View {
    // MARK: Lifecycle

    public init(model: AgendaModel) {
        self.model = model
    }

    // MARK: Public

    public var body: some View {
        Label {
            if let title = model.title {
                Text(title)
            }
        } icon: {
            // swiftlint:disable:next prefer_asset_symbols - the catalogue, and so its symbols, live in the app target
            Image("MenuBarIcon")
                .accessibilityLabel("MinMaxCal")
        }
        .task { await model.run() }
    }

    // MARK: Private

    private let model: AgendaModel
}
