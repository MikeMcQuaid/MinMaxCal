import SwiftUI

/// A square of Liquid Glass around a symbol, the same size whatever the symbol, so icon buttons
/// line up in a column without disturbing it.
package struct GlassIconButtonStyle: ButtonStyle {
    // MARK: Lifecycle

    package init() {}

    // MARK: Package

    #if os(iOS)
    package static let side: CGFloat = 44
    private static let glassSide: CGFloat = 26
    #else
    package static let side: CGFloat = 22
    private static let glassSide: CGFloat = side
    #endif

    package func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .frame(width: Self.glassSide, height: Self.glassSide)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Self.cornerRadius))
            .frame(width: Self.side, height: Self.side)
            .contentShape(.rect(cornerRadius: Self.cornerRadius))
            .opacity(configuration.isPressed ? Self.pressedOpacity : 1)
    }

    // MARK: Private

    private static let cornerRadius: CGFloat = 6
    private static let pressedOpacity = 0.6
}
