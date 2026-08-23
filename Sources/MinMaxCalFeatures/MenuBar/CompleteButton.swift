import SwiftUI

/// Completes a reminder: prominent with Return in a takeover, a plain glass icon in a row. Once
/// completed, the same spot offers to undo it.
public struct CompleteButton: View {
    // MARK: Lifecycle

    public init(isPrimary: Bool, undo: Bool = false, action: @escaping () -> Void) {
        self.isPrimary = isPrimary
        self.undo = undo
        self.action = action
    }

    // MARK: Public

    public var body: some View {
        if isPrimary {
            Button("Complete", action: action)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
        } else {
            Button(action: action) {
                Label(
                    undo ? "Undo" : "Complete",
                    systemImage: undo ? "arrow.uturn.backward.circle" : "checkmark.circle",
                )
                .frame(width: Self.iconSide, height: Self.iconSide)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .help(undo ? "Mark as not completed in Reminders" : "Complete in Reminders")
        }
    }

    // MARK: Private

    /// Every icon button is the same square whatever the symbol's own width.
    private static let iconSide: CGFloat = 16

    private let isPrimary: Bool
    private let undo: Bool
    private let action: () -> Void
}
