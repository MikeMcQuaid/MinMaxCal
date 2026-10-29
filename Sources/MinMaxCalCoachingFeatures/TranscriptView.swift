import MinMaxCalCoachingDomain
import SwiftUI

struct TranscriptView: View {
    // MARK: Internal

    let meeting: Meeting

    var body: some View {
        let turns = meeting.transcriptTurns
        // swiftlint:disable:next closure_body_length - One inline surface.
        DisclosureGroup {
            VStack(
                alignment: .leading,
                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                spacing: 12,
                // swiftlint:disable:next closure_body_length - One inline surface.
            ) {
                Toggle("Follow live", isOn: $followsTranscript).toggleStyle(.checkbox)
                if turns.isEmpty {
                    Text(meeting
                        .isComplete ? "No transcript was captured for this meeting." : "Waiting for recognised speech…")
                        .foregroundStyle(.secondary)
                } else {
                    // swiftlint:disable:next closure_body_length - One inline surface.
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(
                                alignment: .leading,
                                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                                spacing: 16,
                            ) {
                                ForEach(
                                    Array(turns.enumerated()),
                                    id: \.offset,
                                ) { _, turn in
                                    VStack(
                                        alignment: .leading,
                                        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                                        spacing: 4,
                                    ) {
                                        Text("\(turn.timestamp) · \(meeting.name(for: turn.speakerID))")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                        Text(turn.text).textSelection(.enabled)
                                    }
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading,
                                    )
                                }
                                Color.clear.frame(height: 1).id("transcript-end")
                                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                            }.padding(12)
                        }
                        .onChange(of: turns.last) {
                            if followsTranscript {
                                proxy.scrollTo("transcript-end", anchor: .bottom)
                            }
                        }
                        .onChange(of: followsTranscript) {
                            if followsTranscript {
                                proxy.scrollTo("transcript-end", anchor: .bottom)
                            }
                        }
                    }
                    // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                    .frame(height: 220)
                    .background(
                        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                        .quaternary.opacity(0.4),
                        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                        in: .rect(cornerRadius: 10),
                    )
                }
                Text(
                    """
                    English transcription runs on this Mac with a short delay. Words and speaker labels are \
                    estimates.  Renaming a speaker updates the transcript and copied text.
                    """
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            }.padding(.top, 8)
        } label: {
            HStack {
                Text("Transcript").font(.headline)
                Spacer()
                CopyTranscriptButton(meeting: meeting)
                    .labelStyle(.titleAndIcon)
                    .disabled(turns.isEmpty)
            }
        }
    }

    // MARK: Private

    @State private var followsTranscript = true
}
