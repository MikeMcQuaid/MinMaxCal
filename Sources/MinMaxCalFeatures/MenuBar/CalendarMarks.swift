import MinMaxCalDomain
import SwiftUI

/// One small symbol per calendar in its colour, a calendar leaf for events and a list for
/// reminders, overlapping like a stack of coins in a fixed-width column so titles align.
public struct CalendarMarks: View {
    // MARK: Lifecycle

    public init(calendars: [CalendarList], size: CGFloat = 11) {
        self.calendars = calendars
        self.size = size
    }

    // MARK: Public

    public static let columnWidth: CGFloat = 22

    public var body: some View {
        HStack(spacing: -Self.overlap) {
            ForEach(calendars) { list in
                Image(systemName: list.kind == .reminder ? "checklist" : "calendar")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Color(list.colour))
                    .frame(width: size + Self.inset, height: size + Self.inset)
                    .background(.background, in: Circle())
            }
        }
        .frame(width: max(Self.columnWidth, size + Self.inset), alignment: .leading)
        .accessibilityLabel(calendars.map(\.title).joined(separator: ", "))
    }

    // MARK: Private

    private static let overlap: CGFloat = 5
    private static let inset: CGFloat = 4

    private let calendars: [CalendarList]
    private let size: CGFloat
}
