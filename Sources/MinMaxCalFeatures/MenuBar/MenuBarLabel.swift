import SwiftUI

/// The status item's content: the template icon, then the title when there is one. A `Label`
/// here would show its icon only, and lifecycle modifiers on it never run, so the refresh loop is
/// started by the app instead.
public struct MenuBarLabel: View {
    // MARK: Lifecycle

    public init(model: AgendaModel) {
        self.model = model
    }

    // MARK: Public

    public var body: some View {
        // swiftlint:disable:next prefer_asset_symbols - the catalogue, and so its symbols, live in the app target
        Image("MenuBarIcon")
            .accessibilityLabel("MinMaxCal")
        if let title = model.title {
            Text(title)
                .monospacedDigit()
                .baselineOffset(Self.baselineOffset)
        }
    }

    // MARK: Private

    /// The status item sets the text a little high against the icon; a negative offset lowers it.
    private static let baselineOffset: CGFloat = -2

    private let model: AgendaModel
}
