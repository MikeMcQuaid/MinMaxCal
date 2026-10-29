import MinMaxCalCoachingDomain
import SwiftUI

struct MeetingDetailsView: View {
    let model: MeetingModel
    let meeting: Meeting
    let targetShare: Double
    let turnLimit: Double

    var body: some View {
        // swiftlint:disable:next no_magic_numbers - Match the current recording panel.
        VStack(alignment: .leading, spacing: 16) {
            TranscriptView(meeting: meeting)
            if meeting.id == model.current?.id, model.phase == .recording {
                CoachingView(meeting: meeting, targetShare: targetShare, turnLimit: turnLimit)
                Label(model.speakerStatus, systemImage: "waveform")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if model.reduceSpeakerEcho, model.hasMeetingAudio == false {
                    Label(
                        "Waiting for system audio. Microphone speech cannot yet be attributed to you.",
                        systemImage: "speaker.wave.2",
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                DisclosureGroup("Audio levels") {
                    // swiftlint:disable:next no_magic_numbers - Match the current recording panel.
                    VStack(alignment: .leading, spacing: 10) {
                        LevelView(title: "Microphone", level: model.microphoneLevel)
                        LevelView(title: "Meeting audio", level: model.meetingLevel)
                        Text("Your meeting app’s mute button does not mute MinMaxCal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // swiftlint:disable:next no_magic_numbers - Match the current recording panel.
                    .padding(.top, 8)
                }
            }
            SummaryView(meeting: meeting) { speakerID, name in
                Task {
                    await model.rename(speakerID: speakerID, to: name, meetingID: meeting.id)
                }
            }
        }
    }
}
