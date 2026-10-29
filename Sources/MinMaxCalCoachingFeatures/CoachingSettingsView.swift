import MinMaxCalCoachingDomain
import SwiftUI

public struct CoachingSettingsView: View {
    // MARK: Lifecycle

    public init(model: MeetingModel) {
        self.model = model
        _name = State(initialValue: model.myName)
    }

    // MARK: Public

    public var body: some View {
        Section("You") {
            TextField("Your name", text: $name)
                .focused($nameIsFocused)
                .onSubmit { model.myName = name }
                .onChange(of: nameIsFocused) {
                    if nameIsFocused == false {
                        model.myName = name
                    }
                }
                .onChange(of: model.myName) {
                    if nameIsFocused == false {
                        name = model.myName
                    }
                }
            Text(
                """
                Used in new meeting transcripts and to suggest the other person in a one-to-one. Saved meeting \
                names  stay as you labelled them.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Section("Make space for others") {
            LabeledContent(
                "Speaking share target",
                value: model.targetShare.formatted(.percent.precision(.fractionLength(0))),
            )
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            Slider(value: $model.targetShare, in: 0.1 ... 0.7, step: 0.05) { Text("Speaking share target") }
            Picker("Uninterrupted turn cue", selection: $model.turnLimit) {
                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                ForEach([30.0, 45, 60, 90, 120], id: \.self) { seconds in
                    Text(durationText(seconds)).tag(seconds)
                }
            }
            Text(
                """
                These are personal reminders. Adjust for your role: a presentation and a group discussion need \
                different amounts of speaking. For a group discussion, an equal share is roughly 100% divided \
                by the  number of people.
                """
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        Section("Notifications") {
            Text(
                """
                A silent notification appears when your recent share or uninterrupted turn crosses a target. \
                Reminders  need a new crossing and are at least two minutes apart.
                """
            )
            Toggle("Ask to record calendar meetings", isOn: $model.calendarPromptsEnabled)
            Text(
                """
                Events with a conference link qualify, including events without attendees. Prompts appear \
                at the start time and offer Record or Not Now.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("Enable Notifications") { Task {
                await model.enableNotifications()
            }
            }
            if let message = model.notificationMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("History") {
            Picker("Keep meetings", selection: $model.meetingRetention) {
                ForEach([MeetingRetention.twoDays, .oneWeek, .thirtyDays], id: \.self) { retention in
                    Text(retention.title).tag(retention)
                }
            }
            Text(
                """
                Deletes saved transcripts, summaries, statistics and speaker names after recording ends.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Section("How cues work") {
            Text(
                """
                The share cue uses the last five minutes and waits for 30 seconds of detected speech. The turn \
                cue  asks you to finish your thought. Cues appear in the agenda and silent notifications. \
                macOS  notification settings and Focus control banner delivery.
                """
            )
            Text(
                """
                Try asking an open question, waiting a few seconds before responding and inviting someone who \
                has not  spoken. Speaking time measures participation, not the value of a contribution.
                """
            )
        }
    }

    // MARK: Private

    @Bindable private var model: MeetingModel

    @State private var name: String
    @FocusState private var nameIsFocused: Bool
}
