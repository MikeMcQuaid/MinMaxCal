import MinMaxCalAgenda
import SwiftUI

/// The status item's content: the template icon, then the title when there is one. A `Label`
/// here would show its icon only, and lifecycle modifiers on it never run, so the refresh loop is
/// started by the app instead.
public struct MenuBarLabel: View {
    // MARK: Lifecycle

    public init(model: AgendaModel, recordingSymbol: String? = nil) {
        self.model = model
        self.recordingSymbol = recordingSymbol
    }

    // MARK: Public

    public var body: some View {
        if let recordingSymbol {
            Image(systemName: recordingSymbol).accessibilityLabel("MinMaxCal recording a meeting")
        } else {
            // swiftlint:disable:next prefer_asset_symbols - the catalogue, and so its symbols, live in the app target
            Image("MenuBarIcon")
                .accessibilityLabel("MinMaxCal")
        }
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
    private let recordingSymbol: String?
}
