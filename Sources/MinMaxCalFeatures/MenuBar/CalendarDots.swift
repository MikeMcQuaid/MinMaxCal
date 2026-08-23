import MinMaxCalDomain
import SwiftUI

/// One dot per calendar, overlapping like a stack of coins, in a fixed-width column so titles align.
public struct CalendarDots: View {
    // MARK: Lifecycle

    public init(calendars: [CalendarList], diameter: CGFloat = 9) {
        self.calendars = calendars
        self.diameter = diameter
    }

    // MARK: Public

    public static let columnWidth: CGFloat = 22

    public var body: some View {
        HStack(spacing: -Self.overlap) {
            ForEach(calendars) { list in
                Circle()
                    .fill(Color(list.colour))
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(width: max(Self.columnWidth, diameter), alignment: .leading)
        .accessibilityLabel(calendars.map(\.title).joined(separator: ", "))
    }

    // MARK: Private

    private static let overlap: CGFloat = 3

    private let calendars: [CalendarList]
    private let diameter: CGFloat
}
