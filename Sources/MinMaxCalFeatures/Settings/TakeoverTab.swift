import MinMaxCalDomain
import SwiftUI

struct TakeoverTab: View {
    // MARK: Internal

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section("Triggers") {
                Toggle("Take over at the start of an accepted event", isOn: $model.takeover.onEventStart)
                Toggle("Take over when a reminder is due", isOn: $model.takeover.onReminderDue)
            }
            Section("Snooze") {
                TextField("Durations in minutes", text: snoozeDurations)
            }
            Section("Previews") {
                ForEach(AgendaItem.Sample.allCases, id: \.self) { sample in
                    LabeledContent(sample.name) {
                        Button("Preview") {
                            model.preview(sample)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    private var snoozeDurations: Binding<String> {
        Binding(
            get: { model.takeover.snoozeMinutes.map(String.init).joined(separator: ", ") },
            set: { model.takeover.snoozeMinutes = ListField.integers(from: $0) },
        )
    }
}
