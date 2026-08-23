import MinMaxCalDomain
import SwiftUI

/// The calendars, location, organiser, attendees, response and notes of an item, shared by an
/// expanded agenda row and the takeover panel.
public struct ItemDetails: View {
    // MARK: Lifecycle

    public init(item: AgendaItem) {
        self.item = item
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            Grid(
                alignment: .leadingFirstTextBaseline,
                horizontalSpacing: Self.columnSpacing,
                verticalSpacing: Self.rowSpacing,
            ) {
                detail("Calendars", item.calendars.map(\.title).joined(separator: ", "))
                if let location = item.location, location.isEmpty == false {
                    detail("Location", location)
                }
                if let organiser = item.organiser {
                    detail("Organiser", organiser.name)
                }
                if item.attendees.isEmpty == false {
                    GridRow {
                        Text("Attendees")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: Self.lineSpacing) {
                            ForEach(item.attendees, id: \.self) { attendee in
                                Label(attendee.name, systemImage: Self.symbol(for: attendee.response))
                            }
                        }
                    }
                }
                if let response = item.currentUserResponse {
                    detail("Your response", Self.description(of: response))
                }
            }
            if let notes = item.notes, notes.isEmpty == false {
                NotesText(notes)
            }
        }
    }

    // MARK: Private

    private static let sectionSpacing: CGFloat = 8
    private static let columnSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 4
    private static let lineSpacing: CGFloat = 2

    private let item: AgendaItem

    private func detail(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }

    private static func symbol(for response: AttendeeResponse) -> String {
        switch response {
        case .accepted:
            "checkmark.circle.fill"

        case .declined:
            "xmark.circle"

        case .tentative:
            "questionmark.circle"

        case .pending,
             .unknown:
            "circle"
        }
    }

    private static func description(of response: AttendeeResponse) -> String {
        switch response {
        case .accepted:
            "Accepted"

        case .declined:
            "Declined"

        case .tentative:
            "Tentative"

        case .pending:
            "Not answered"

        case .unknown:
            "Unknown"
        }
    }
}
