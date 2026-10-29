#if !os(watchOS)
import MinMaxCalDomain
import SwiftUI

public struct JoinButton: View {
    // MARK: Lifecycle

    public init(
        link: JoinLink,
        isPrimary: Bool,
        recordsMeeting: Bool = false,
        title: String? = nil,
        action: @escaping (JoinLink) -> Void,
    ) {
        self.link = link
        self.isPrimary = isPrimary
        self.action = action
        self.title = title
        self.recordsMeeting = recordsMeeting
    }

    // MARK: Public

    public var body: some View {
        if isPrimary {
            button
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .keyboardShortcut(.defaultAction)
        } else if title != nil {
            button
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(help)
        } else {
            button
                .buttonStyle(GlassIconButtonStyle())
                .help(help)
        }
    }

    // MARK: Private

    private let link: JoinLink
    private let isPrimary: Bool
    private let action: (JoinLink) -> Void
    private let title: String?
    private let recordsMeeting: Bool

    private var help: String {
        switch link.service {
        case .other:
            recordsMeeting ? "Open the link and record" : "Open the link"

        case .facetime,
             .jitsi,
             .meet,
             .teams,
             .zoom:
            "\(recordsMeeting ? "Join and record" : "Join") with \(link.service.name)"
        }
    }

    private var button: some View {
        Button {
            action(link)
        } label: {
            Label {
                Text(title ?? (recordsMeeting ? "Join and Record" : "Join"))
            } icon: {
                Image(systemName: isPrimary ? "video.fill" : "video")
                    .overlay(alignment: .bottomTrailing) {
                        if recordsMeeting {
                            Circle()
                                .fill(.red)
                                // swiftlint:disable:next no_magic_numbers - Compact recording badge.
                                .frame(width: 5, height: 5)
                                .accessibilityHidden(true)
                        }
                    }
            }
        }
    }
}
#endif
