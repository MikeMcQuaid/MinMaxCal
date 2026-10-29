import SwiftUI

struct CoachingRow: ViewModifier {
    // MARK: Internal

    let label: String
    let hint: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .contentShape(.rect)
            // swiftlint:disable:next no_magic_numbers - Match the agenda row focus shape.
            .background(hovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
            .onHover { hovered = $0 }
            .focusable(interactions: .activate)
            .onKeyPress(keys: [.return, .space]) { _ in
                action()
                return .handled
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAction { action() }
            .help(hint)
    }

    // MARK: Private

    @State private var hovered = false
}
