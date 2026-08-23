import SwiftUI

/// Completes a reminder: prominent with Return in a takeover, a plain glass icon in a row.
public struct CompleteButton: View {
    // MARK: Lifecycle

    public init(isPrimary: Bool, action: @escaping () -> Void) {
        self.isPrimary = isPrimary
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
                Label("Complete", systemImage: "checkmark.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .help("Complete in Reminders")
        }
    }

    // MARK: Private

    private let isPrimary: Bool
    private let action: () -> Void
}
