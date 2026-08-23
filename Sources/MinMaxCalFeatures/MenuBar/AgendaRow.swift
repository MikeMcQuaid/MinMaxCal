import Foundation
import MinMaxCalDomain
import SwiftUI

/// One item as a table row: colour dots, title, the action column, then the start and end
/// times in columns of their own so every row's times line up.
public struct AgendaRow: View {
    // MARK: Lifecycle

    public init(
        item: AgendaItem,
        style: Style,
        onJoin: @escaping (JoinLink) -> Void,
        onComplete: @escaping () -> Void = {},
        joinIsPrimary: Bool = false,
    ) {
        self.item = item
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
            CalendarDots(calendars: item.calendars)
            title
                .frame(maxWidth: .infinity, alignment: .leading)
            actions
                .frame(width: Self.actionColumnWidth)
            times
        }
    }

    // MARK: Private

    private static let statusPadding: CGFloat = 6
    private static let spacing: CGFloat = 8
    private static let takeoverTitleLines = 2
    private static let actionColumnWidth: CGFloat = 64

    private static let agendaTimeWidth: CGFloat = 58
    private static let takeoverTimeWidth: CGFloat = 96

    private let item: AgendaItem
    private let style: Style
    private let joinIsPrimary: Bool
    private let onComplete: () -> Void
    private let onJoin: (JoinLink) -> Void

    private var timeColumnWidth: CGFloat {
        style == .agenda ? Self.agendaTimeWidth : Self.takeoverTimeWidth
    }

    private var timeFont: Font {
        style == .agenda ? .body : .title2
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

    /// A fixed-width column keeps the times aligned whether a row has a call, a checkbox or neither.
    private var actions: some View {
        HStack(spacing: Self.spacing) {
            if style == .agenda, item.kind == .reminder {
                CompleteButton(isPrimary: false, action: onComplete)
            }
            if let link = item.joinLink {
                JoinButton(link: link, isPrimary: joinIsPrimary, action: onJoin)
            }
        }
    }

    @ViewBuilder private var times: some View {
        if item.isAllDay {
            Text("All day")
                .font(timeFont)
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth + timeColumnWidth, alignment: .leading)
        } else {
            Text(item.start.formatted(date: .omitted, time: .shortened))
                .font(timeFont)
                .monospacedDigit()
                .frame(width: timeColumnWidth, alignment: .trailing)
            Text(item.end.map { "–\($0.formatted(date: .omitted, time: .shortened))" } ?? "")
                .font(timeFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, alignment: .leading)
        }
    }
}
