import MinMaxCalAgenda
import MinMaxCalCoachingDomain
import MinMaxCalDomain
import SwiftUI

struct MeetingChoiceRow: View {
    let meeting: CalendarMeeting
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AgendaRow(
                item: AgendaItem(
                    members: [],
                    kind: .event,
                    title: meeting.title,
                    start: meeting.start,
                    end: meeting.end,
                    isAllDay: meeting.isAllDay,
                ),
                style: .agenda,
            )
            .overlay(alignment: .trailing) {
                if selected {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
            }
        }
        .modifier(CoachingRow(
            label: meeting.title + (selected ? ", selected" : ""),
            hint: "Uses this meeting’s title and invitees",
            action: action,
        ))
    }

    // MARK: Private
}
