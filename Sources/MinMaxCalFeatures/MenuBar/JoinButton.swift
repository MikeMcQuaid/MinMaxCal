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
            }
            .buttonStyle(GlassIconButtonStyle())
            .help(help)
        }
    }

    // MARK: Private

    private let link: JoinLink
    private let isPrimary: Bool
    private let action: (JoinLink) -> Void

    private var help: String {
        switch link.service {
        case .other:
            "Open the link"

        case .facetime,
             .jitsi,
             .meet,
             .teams,
             .zoom:
            "Join with \(link.service.name)"
        }
    }
}
