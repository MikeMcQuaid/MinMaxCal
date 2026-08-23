import SwiftUI

/// A square of Liquid Glass around a symbol, the same size whatever the symbol, so icon buttons
/// line up in a column without disturbing it.
struct GlassIconButtonStyle: ButtonStyle {
    // MARK: Internal

    static let side: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .frame(width: Self.side, height: Self.side)
            .contentShape(.rect(cornerRadius: Self.cornerRadius))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Self.cornerRadius))
            .opacity(configuration.isPressed ? Self.pressedOpacity : 1)
    }

    // MARK: Private

    private static let cornerRadius: CGFloat = 6
    private static let pressedOpacity = 0.6
}
