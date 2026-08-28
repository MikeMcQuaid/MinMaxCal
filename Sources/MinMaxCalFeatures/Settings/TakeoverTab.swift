import MinMaxCalDomain
import SwiftUI

struct TakeoverTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle("Take over at the start of an accepted event", isOn: $model.takeover.onEventStart)
                Toggle("Take over when a reminder is due", isOn: $model.takeover.onReminderDue)
            } footer: {
                Text("A takeover covers every display until you join, complete, snooze or dismiss it.")
                Text("Accepted means you said yes, you organised it or it has no attendees.")
                Text(
                    "Unanswered and tentative invitations, all-day events and reminders without a time never take over."
                )
            }
            Section {
                TextField(
                    "Snooze durations in minutes",
                    value: $model.takeover.snoozeMinutes,
                    format: ListField.Integers(),
                )
            } footer: {
                Text("The choices a reminder's Snooze button offers. Separate with commas and press Return.")
                Text("To see a takeover, right-click any row in the agenda and choose Preview Takeover.")
            }
        }
        .formStyle(.grouped)
    }
}
