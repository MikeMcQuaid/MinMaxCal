import Foundation
import MinMaxCalDomain
import SwiftUI

/// The shared agenda and takeover row, with platform-specific dimensions.
public struct AgendaRow: View {
    // MARK: Lifecycle

    public init(
        item: AgendaItem,
        style: Style,
        onJoin: ((JoinLink) -> Void)? = nil,
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
            CalendarMarks(
                calendars: item.calendars,
                size: style == .agenda ? Self.agendaMarkSize : Self.takeoverMarkSize,
            )
            .padding(.trailing, style == .agenda ? 0 : Self.takeoverMarkGap)
            #if os(watchOS)
            VStack(alignment: .leading, spacing: Self.spacing) {
                title
                Text(range)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #else
            title
                .frame(maxWidth: .infinity, alignment: .leading)
            times
            action
                .frame(width: style == .agenda ? GlassIconButtonStyle.side : nil)
            #endif
        }
        #if !os(watchOS)
        .frame(height: style == .agenda ? agendaRowHeight : Self.takeoverRowHeight)
        #endif
        .accessibilityElement(children: .contain)
    }

    // MARK: Internal

    static let usesTwelveHourClock = Date.now
        .formatted(date: .omitted, time: .shortened)
        .contains(where: \.isLetter)

    /// Reserve both columns even for reminders, which have only a start time.
    @ViewBuilder var times: some View {
        if style == .takeover {
            Text(range)
                .font(timeFont)
                .monospacedDigit()
        } else {
            HStack(spacing: Self.spacing) {
                if item.isAllDay {
                    Text("All day")
                        .foregroundStyle(.secondary)
                        .frame(
                            width: (timeWidth + Self.spacing) * Self.timeColumnCount + Self.dashColumnWidth,
                            alignment: .leading,
                        )
                } else {
                    Text(Self.clock(item.start))
                        .frame(width: timeWidth, alignment: .trailing)
                    Text(item.end == nil ? "" : "–")
                        .frame(width: Self.dashColumnWidth)
                        .accessibilityHidden(true)
                    Text(item.end.map(Self.clock) ?? "")
                        .frame(width: timeWidth, alignment: .trailing)
                }
            }
            .font(timeFont)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
        }
    }

    // MARK: Private

    private static let spacing: CGFloat = 4
    private static let dashColumnWidth: CGFloat = 6
    private static let timeColumnCount: CGFloat = 2
    private static let statusPadding: CGFloat = 6
    private static let takeoverTitleLines = 2
    private static let takeoverMarkSize: CGFloat = 24
    private static let takeoverMarkGap: CGFloat = 8
    private static let takeoverRowHeight: CGFloat = 44

    @ScaledMetric(relativeTo: Self.agendaTimeStyle)
    private var timeWidth: CGFloat = Self.agendaTimeWidth

    @ScaledMetric(relativeTo: .body)
    private var agendaRowHeight: CGFloat = Self.agendaMinimumHeight

    private let item: AgendaItem
    private let style: Style
    private let joinIsPrimary: Bool
    private let onComplete: () -> Void
    private let onUncomplete: () -> Void
    private let onJoin: ((JoinLink) -> Void)?

    private var timeFont: Font {
        if style == .agenda {
            .system(Self.agendaTimeStyle)
        } else {
            .title2
        }
    }

    private var range: String {
        if item.isAllDay {
            return "All day"
        }
        guard let end = item.end else {
            return Self.clock(item.start)
        }

        return "\(Self.clock(item.start)) – \(Self.clock(end))"
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
            Text(item.displayTitle)
                .font(style == .agenda ? .body : .title)
                #if os(watchOS)
                .fixedSize(horizontal: false, vertical: true)
                #else
                .lineLimit(style == .agenda ? 1 : Self.takeoverTitleLines)
                #endif
                .truncationMode(.tail)
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

    #if !os(watchOS)
    /// The action column sits at the far right so the times stay aligned whatever a row offers.
    /// Exactly one square: a reminder's tick (or undo), else the call's join button, else air.
    @ViewBuilder private var action: some View {
        if style == .agenda, item.kind == .reminder {
            CompleteButton(
                isPrimary: false,
                undo: item.isCompleted,
                action: item.isCompleted ? onUncomplete : onComplete,
            )
        } else if let link = item.joinLink, let onJoin {
            JoinButton(link: link, isPrimary: joinIsPrimary, action: onJoin)
        } else {
            Color.clear
        }
    }
    #endif

    /// Two-digit hours keep every time the same width, so the dash sits evenly between them.
    private static func clock(_ date: Date) -> String {
        let hour: Date.FormatStyle.Symbol
            .Hour = usesTwelveHourClock ? .twoDigits(amPM: .abbreviated) : .twoDigits(amPM: .omitted)
        return date.formatted(.dateTime.hour(hour).minute(.twoDigits))
    }
}
