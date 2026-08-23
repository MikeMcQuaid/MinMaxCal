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
        onUncomplete: @escaping () -> Void = {},
        joinIsPrimary: Bool = false,
    ) {
        self.item = item
        self.style = style
        self.onJoin = onJoin
        self.joinIsPrimary = joinIsPrimary
        self.onComplete = onComplete
        self.onUncomplete = onUncomplete
    }

    // MARK: Public

    public enum Style {
        case agenda
        case takeover
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Self.spacing) {
            CalendarDots(calendars: item.calendars)
            title
                .frame(maxWidth: .infinity, alignment: .leading)
            times
            action
                .frame(width: style == .agenda ? GlassIconButtonStyle.side : nil)
        }
        .frame(height: style == .agenda ? Self.agendaRowHeight : Self.takeoverRowHeight)
    }

    // MARK: Private

    private static let statusPadding: CGFloat = 6
    private static let spacing: CGFloat = 6
    private static let takeoverTitleLines = 2
    private static let dashColumnWidth: CGFloat = 8
    private static let agendaRowHeight: CGFloat = 24
    private static let takeoverRowHeight: CGFloat = 44
    /// Wide enough for `10:05`, or `10:05 PM` where the clock has a period.
    private static let agendaTimeWidth: CGFloat = usesTwelveHourClock ? twelveHourTimeWidth : twentyFourHourTimeWidth
    private static let twelveHourTimeWidth: CGFloat = 66
    private static let twentyFourHourTimeWidth: CGFloat = 44
    private static let takeoverTimeWidth: CGFloat = agendaTimeWidth * takeoverScale
    private static let takeoverScale: CGFloat = 1.7
    private static let usesTwelveHourClock = Date.now
        .formatted(date: .omitted, time: .shortened)
        .contains(where: \.isLetter)

    private let item: AgendaItem
    private let style: Style
    private let joinIsPrimary: Bool
    private let onComplete: () -> Void
    private let onUncomplete: () -> Void
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
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
            if let status {
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, Self.statusPadding)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    /// The action column sits at the far right so the times stay aligned whatever a row offers.
    /// Exactly one square: a reminder's tick (or undo), else the call's join button, else air.
    @ViewBuilder private var action: some View {
        if style == .agenda, item.kind == .reminder {
            CompleteButton(
                isPrimary: false,
                undo: item.isCompleted,
                action: item.isCompleted ? onUncomplete : onComplete,
            )
        } else if let link = item.joinLink {
            JoinButton(link: link, isPrimary: joinIsPrimary, action: onJoin)
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var times: some View {
        if item.isAllDay {
            Text("All day")
                .font(timeFont)
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth + Self.dashColumnWidth + timeColumnWidth, alignment: .leading)
        } else {
            Text(item.start.formatted(date: .omitted, time: .shortened))
                .font(timeFont)
                .monospacedDigit()
                .frame(width: timeColumnWidth, alignment: .trailing)
            Text(item.end == nil ? "" : "–")
                .font(timeFont)
                .foregroundStyle(.secondary)
                .frame(width: Self.dashColumnWidth)
            Text(item.end?.formatted(date: .omitted, time: .shortened) ?? "")
                .font(timeFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, alignment: .trailing)
        }
    }
}
