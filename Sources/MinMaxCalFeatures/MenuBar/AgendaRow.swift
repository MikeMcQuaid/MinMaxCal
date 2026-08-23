import Foundation
import MinMaxCalDomain
import SwiftUI

public struct AgendaRow: View {
    // MARK: Lifecycle

    public init(
        item: AgendaItem,
        now: Date,
        style: Style,
        onJoin: @escaping (JoinLink) -> Void,
        onComplete: @escaping () -> Void = {},
        joinIsPrimary: Bool = false,
    ) {
        self.item = item
        self.now = now
        self.style = style
        self.onJoin = onJoin
        self.joinIsPrimary = joinIsPrimary
        self.onComplete = onComplete
    }

    // MARK: Public

    public enum Style {
        case agenda
        case takeover
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.spacing) {
            if style == .agenda, item.kind == .reminder {
                Toggle(isOn: completion) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .help("Complete in Reminders")
            }
            CalendarDots(calendars: item.calendars)
            title
            Spacer(minLength: Self.spacing)
            joinColumn
            Text(timeRange)
                .font(style == .agenda ? .body : .title2)
                .monospacedDigit()
            CountdownText(item: item, now: now)
                .font(style == .agenda ? .caption : .title3)
                .foregroundStyle(.secondary)
                .frame(width: Self.countdownWidth, alignment: .leading)
        }
    }

    // MARK: Private

    private static let statusPadding: CGFloat = 6
    private static let spacing: CGFloat = 8
    private static let takeoverTitleLines = 2
    private static let joinColumnWidth: CGFloat = 32
    private static let countdownWidth: CGFloat = 44

    private let item: AgendaItem
    private let now: Date
    private let style: Style
    private let joinIsPrimary: Bool
    private let onComplete: () -> Void
    private let onJoin: (JoinLink) -> Void

    private var completion: Binding<Bool> {
        Binding(
            get: { false },
            set: { ticked in
                if ticked {
                    onComplete()
                }
            },
        )
    }

    private var status: String? {
        switch item.currentUserResponse {
        case .pending:
            "Invitation"

        case .tentative:
            "Tentative"

        case .accepted,
             .declined,
             nil,
             .unknown:
            nil
        }
    }

    private var timeRange: String {
        if item.isAllDay {
            return "All day"
        }
        let start = item.start.formatted(date: .omitted, time: .shortened)
        guard let end = item.end else {
            return start
        }

        return "\(start)–\(end.formatted(date: .omitted, time: .shortened))"
    }

    private var title: some View {
        HStack(spacing: Self.statusPadding) {
            Text(item.title.isEmpty ? "Untitled" : item.title)
                .font(style == .agenda ? .body : .title)
                .lineLimit(style == .agenda ? 1 : Self.takeoverTitleLines)
            if let status {
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, Self.statusPadding)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    /// A fixed-width column keeps every row's time aligned whether or not it has a call.
    @ViewBuilder private var joinColumn: some View {
        if let link = item.joinLink {
            JoinButton(link: link, isPrimary: joinIsPrimary, action: onJoin)
                .frame(minWidth: Self.joinColumnWidth)
        } else {
            Color.clear
                .frame(width: Self.joinColumnWidth, height: 1)
        }
    }
}
