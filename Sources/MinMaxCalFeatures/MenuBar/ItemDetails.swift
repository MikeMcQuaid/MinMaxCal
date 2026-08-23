import MinMaxCalDomain
import SwiftUI

/// The calendars, location, organiser, attendees, response, repeat and notes of an item, shared
/// by an expanded agenda row and the takeover panel.
public struct ItemDetails: View {
    // MARK: Lifecycle

    public init(item: AgendaItem, rules: MatchingRules, showsAttendees: Bool = false) {
        self.item = item
        self.rules = rules
        _showsAttendees = State(initialValue: showsAttendees)
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            grid
            if let notes, notes.isEmpty == false {
                NotesText(notes)
            }
        }
    }

    // MARK: Private

    private static let sectionSpacing: CGFloat = 8
    private static let columnSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 4
    private static let lineSpacing: CGFloat = 2
    private static let countSpacing: CGFloat = 10
    private static let counted: [AttendeeResponse] = [.accepted, .tentative, .declined, .pending]

    @State private var showsAttendees = false

    private let item: AgendaItem
    private let rules: MatchingRules

    private var notes: String? {
        item.notes.map { NotesTidier.removingBoilerplate(from: $0, hasCallLink: item.joinLink != nil) }
    }

    private var grid: some View {
        Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: Self.columnSpacing,
            verticalSpacing: Self.rowSpacing,
        ) {
            detail("Calendars", item.calendars.map(\.title).joined(separator: ", "))
            if let location = item.location, location.isEmpty == false {
                GridRow {
                    Text("Location")
                        .foregroundStyle(.secondary)
                    LocationLink(location, rules: rules)
                }
            }
            if let organiser = item.organiser {
                detail("Organiser", organiser.name)
            }
            if item.attendees.isEmpty == false {
                GridRow {
                    Text("Attendees")
                        .foregroundStyle(.secondary)
                    attendees
                }
            }
            if let response = item.currentUserResponse {
                detail("Your response", Self.description(of: response))
            }
            if let recurrence = item.recurrence {
                detail("Repeats", recurrence.description)
            }
        }
    }

    /// A count per response until clicked, then everyone by name.
    private var attendees: some View {
        Button {
            showsAttendees.toggle()
        } label: {
            if showsAttendees {
                VStack(alignment: .leading, spacing: Self.lineSpacing) {
                    ForEach(item.attendees, id: \.self) { attendee in
                        Label(attendee.name, systemImage: Self.symbol(for: attendee.response))
                    }
                }
            } else {
                HStack(spacing: Self.countSpacing) {
                    ForEach(Self.counted, id: \.self) { response in
                        let count = item.attendees.count { $0.response == response }
                        if count > 0 {
                            Label(String(count), systemImage: Self.symbol(for: response))
                                .help(Self.description(of: response))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help(showsAttendees ? "Show the counts" : "Show everyone")
    }

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
