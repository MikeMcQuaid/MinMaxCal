import MinMaxCalDomain
import SwiftUI

struct TakeoverTab: View {
    // MARK: Internal

    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            triggers
            sound
            snooze
        }
        .formStyle(.grouped)
    }

    // MARK: Private

    private var triggers: some View {
        Section {
            Toggle("Take over at the start of an accepted event", isOn: $model.takeover.onEventStart)
            Toggle("Take over when a reminder is due", isOn: $model.takeover.onReminderDue)
        } footer: {
            Text("A takeover covers every display until you join, complete, snooze or dismiss it.")
            Text("Accepted means you said yes, you organised it or it has no attendees.")
            Text("Unanswered and tentative invitations, all-day events and reminders without a time never take over.")
        }
    }

    private var sound: some View {
        Section {
            HStack {
                Picker("Sound", selection: $model.takeover.sound) {
                    Text("None").tag(nil as TakeoverSound?)
                    Divider()
                    ForEach(model.sounds, id: \.self) { sound in
                        Text(sound.rawValue).tag(sound as TakeoverSound?)
                    }
                }
                .onChange(of: model.takeover.sound) { _, sound in sound?.play() }
                Button {
                    model.takeover.sound?.play()
                } label: {
                    Label("Play", systemImage: "speaker.wave.2")
                }
                .buttonStyle(GlassIconButtonStyle())
                .help("Play the sound")
                .disabled(model.takeover.sound == nil)
            }
        } footer: {
            Text("Played once as a takeover appears, previews included.")
            Text("Audio files in your Library's Sounds folder are listed with the system's.")
        }
    }

    private var snooze: some View {
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
}
