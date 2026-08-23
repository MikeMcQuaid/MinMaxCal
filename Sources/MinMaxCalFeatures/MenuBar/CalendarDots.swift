import MinMaxCalDomain
import SwiftUI

// MARK: - CalendarDots

public struct CalendarDots: View {
    // MARK: Lifecycle

    public init(calendars: [CalendarList]) {
        self.calendars = calendars
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(calendars) { calendar in
                Circle()
                    .fill(Color(calendar.colour))
                    .frame(width: Self.diameter, height: Self.diameter)
            }
        }
        .accessibilityLabel(calendars.map(\.title).joined(separator: ", "))
    }

    // MARK: Private

    private static let diameter: CGFloat = 8
    private static let spacing: CGFloat = 3

    private let calendars: [CalendarList]
}

extension Color {
    init(_ colour: ListColour) {
        self.init(red: colour.red, green: colour.green, blue: colour.blue, opacity: colour.alpha)
    }
}
