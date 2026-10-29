import SwiftUI

struct MeetingSetupView: View {
    // MARK: Lifecycle

    init(model: MeetingModel) {
        self.model = model
    }

    // MARK: Internal

    var body: some View {
        // swiftlint:disable:next no_magic_numbers - Panel sizing.
        VStack(alignment: .leading, spacing: 14) {
            Text("Leave room for the next voice.").font(.callout).foregroundStyle(.secondary)
            CalendarSetupView(model: model).disabled(model.phase != .idle)
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            VStack(alignment: .leading, spacing: 10) {
                TextField("Meeting name", text: $model.title)
                    .textFieldStyle(.automatic)
                LabeledContent("Other person") {
                    HStack {
                        TextField("Blank for a group meeting", text: $model.otherParticipantName)
                            .textFieldStyle(.automatic)
                        Button("Clear Other Person", systemImage: "xmark.circle.fill") {
                            model.otherParticipantName = ""
                        }
                        .labelStyle(.iconOnly)
                        .help("Clear for a group call")
                        .disabled(model.otherParticipantName.isEmpty)
                    }
                }
                Text("Suggested from your name and calendar. Clear for a group call.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(model.phase != .idle)
            if model.modelState != .ready {
                Text("Download speech models in Settings → Coaching before recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Audio stays on this Mac. Let participants know you are analysing and transcribing the meeting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            await model.refreshCalendar()
        }
    }

    // MARK: Private

    @Bindable private var model: MeetingModel
}
