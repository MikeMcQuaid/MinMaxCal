import MinMaxCalDomain
import SwiftUI

/// One small symbol per calendar in its colour, a calendar leaf for events and a list for
/// reminders, overlapping like a stack of coins in a fixed-width column so titles align.
public struct CalendarMarks: View {
    // MARK: Lifecycle

    public init(calendars: [CalendarList], size: CGFloat = 11, columnWidth: CGFloat = 22) {
        self.calendars = calendars
        self.size = size
        self.columnWidth = columnWidth
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: -markWidth * Self.overlap) {
            ForEach(calendars) { list in
                // A solid tile in the calendar's colour, so a mark fully covers the one beneath it.
                RoundedRectangle(cornerRadius: markWidth * Self.cornerShare)
                    .fill(Color(list.colour))
                    .overlay {
                        Image(systemName: list.kind == .reminder ? "checklist" : "calendar")
                            .font(.system(size: size * Self.glyphShare, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: markWidth, height: markWidth)
            }
        }
        // Calendar colours are pastel by convention; a little darker reads against any background.
        .brightness(Self.darkening)
        .frame(width: max(columnWidth, stackWidth), alignment: .leading)
        .accessibilityLabel(calendars.map(\.title).joined(separator: ", "))
    }

    // MARK: Private

    /// How much of a mark the next one covers.
    private static let overlap: CGFloat = 0.7
    private static let cornerShare: CGFloat = 0.25
    private static let glyphShare: CGFloat = 0.7
    private static let darkening = -0.12
    private static let inset: CGFloat = 4

    private let calendars: [CalendarList]
    private let size: CGFloat
    private let columnWidth: CGFloat

    private var markWidth: CGFloat {
        size + Self.inset
    }

    /// The first mark in full, then what each overlapping one adds.
    private var stackWidth: CGFloat {
        markWidth + CGFloat(max(0, calendars.count - 1)) * markWidth * (1 - Self.overlap)
    }
}
