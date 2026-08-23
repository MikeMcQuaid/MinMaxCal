import MinMaxCalDomain
import SwiftUI

public struct JoinButton: View {
    // MARK: Lifecycle

    public init(link: JoinLink, isPrimary: Bool, action: @escaping (JoinLink) -> Void) {
        self.link = link
        self.isPrimary = isPrimary
        self.action = action
    }

    // MARK: Public

    public var body: some View {
        if isPrimary {
            Button {
                action(link)
            } label: {
                Label("Join", systemImage: "video.fill")
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        } else {
            Button {
                action(link)
            } label: {
                Label("Join", systemImage: "video")
                    .frame(width: Self.iconSide, height: Self.iconSide)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .help(help)
        }
    }

    // MARK: Private

    /// Every icon button is the same square whatever the symbol's own width.
    private static let iconSide: CGFloat = 16

    private let link: JoinLink
    private let isPrimary: Bool
    private let action: (JoinLink) -> Void

    private var help: String {
        switch link.service {
        case .other:
            "Open the link"

        case .jitsi,
             .meet,
             .zoom:
            "Join with \(link.serviceName)"
        }
    }
}
