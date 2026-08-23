import MinMaxCalDomain
import SwiftUI

/// One dot per calendar, overlapping like a stack of coins, in a fixed-width column so titles align.
public struct CalendarDots: View {
    // MARK: Lifecycle

    public init(calendars: [CalendarList]) {
        self.calendars = calendars
    }

    // MARK: Public

    public static let columnWidth: CGFloat = 22

    public var body: some View {
        HStack(spacing: -Self.overlap) {
            ForEach(calendars) { list in
                Circle()
                    .fill(Color(list.colour))
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                    .frame(width: Self.diameter, height: Self.diameter)
            }
        }
        .frame(width: Self.columnWidth, alignment: .leading)
        .accessibilityLabel(calendars.map(\.title).joined(separator: ", "))
    }

    // MARK: Private

    private static let diameter: CGFloat = 9
    private static let overlap: CGFloat = 3

    private let calendars: [CalendarList]
}
