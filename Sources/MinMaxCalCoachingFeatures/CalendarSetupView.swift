import SwiftUI

struct CalendarSetupView: View {
    let model: MeetingModel

    var body: some View {
        VStack(
            alignment: .leading,
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            spacing: 10,
        ) {
            UpcomingMeetingsView(model: model)
            if model.calendarMeeting != nil {
                Button("Use Manual Details") { model.selectCalendarMeeting(nil) }
                    .font(.caption)
            }
            if let meeting = model.calendarMeeting, meeting.participantNames.isEmpty == false {
                DisclosureGroup("Invitees") {
                    Text(meeting.participantNames.joined(separator: ", "))
                        .font(.caption)
                        .textSelection(.enabled)
                    Text("Invitations do not identify voices or prove attendance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let message = model.calendarMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
