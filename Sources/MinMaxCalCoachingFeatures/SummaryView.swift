import Charts
import MinMaxCalCoachingDomain
import SwiftUI
import UniformTypeIdentifiers

// MARK: - SummaryView

struct SummaryView: View {
    // MARK: Internal

    let meeting: Meeting
    let rename: (String, String) -> Void

    var body: some View {
        let statistics = MeetingStatistics(meeting: meeting)
        let ownStatistics = statistics.speakers.first { $0.id == "me" }
        VStack(
            alignment: .leading,
            // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
            spacing: 16,
            // swiftlint:disable:next closure_body_length - One inline surface.
        ) {
            HStack(
                alignment: .top,
                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                spacing: 12,
            ) {
                MetricView(
                    title: "Your share of speech",
                    value: meeting.hasUnverifiedSpeech ? "Unknown" : (ownStatistics?.speakingShare ?? 0)
                        .formatted(.percent.precision(.fractionLength(0))),
                )
                MetricView(
                    title: "Your longest turn",
                    value: meeting.hasUnverifiedSpeech ? "Unknown" : durationText(ownStatistics?.longestTurn ?? 0),
                )
                MetricView(
                    title: "Others’ longest turn",
                    value: meeting
                        .hasUnverifiedSpeech ? "Unknown" :
                        durationText(statistics.speakers.filter { $0.id != "me" }.map(\.longestTurn).max() ?? 0),
                )
            }
            if meeting.hasUnverifiedSpeech {
                Label(
                    """
                    Some microphone speech had no matching playback audio, so it could be you or sound from your \
                    speakers. It has not been counted as you. Shares and turn comparisons are unavailable; the \
                    times below show only detected segments. Check the meeting app’s audio output before the \
                    next recording.
                    """,
                    systemImage: "questionmark.circle",
                ).foregroundStyle(.orange)
            }
            if let notice = meeting.notice {
                Label(notice, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            Text("Who spoke").font(.headline)
            VStack(
                alignment: .leading,
                // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                spacing: 12,
                // swiftlint:disable:next closure_body_length - One inline surface.
            ) {
                // swiftlint:disable:next closure_body_length - One inline surface.
                ForEach(statistics.speakers) { speaker in
                    VStack(
                        alignment: .leading,
                        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                        spacing: 6,
                        // swiftlint:disable:next closure_body_length - One inline surface.
                    ) {
                        HStack {
                            Button {
                                editingSpeaker = speaker.id
                                speakerName = meeting.name(for: speaker.id)
                            } label: {
                                Label(
                                    meeting.name(for: speaker.id),
                                    systemImage: speaker.id == "me" ? "person.fill" : "person",
                                )
                                .lineLimit(1)
                            }
                            .buttonStyle(.glass)
                            .disabled(speaker.id == "unverified-microphone")
                            .help("Rename this speaker")
                            Spacer()
                            Text(meeting.hasUnverifiedSpeech ? "Unknown" : speaker.speakingShare
                                .formatted(.percent.precision(.fractionLength(0))))
                                .monospacedDigit()
                        }
                        HStack {
                            if meeting.hasUnverifiedSpeech == false {
                                ProgressView(value: speaker.speakingShare)
                                    .tint(speaker.id == "me" ? .teal : .blue)
                            }
                            Text(
                                """
                                \(durationText(speaker.speakingTime)) speaking · \
                                \(durationText(speaker.currentTurn)) current · \(durationText(speaker.longestTurn)) \
                                longest
                                """
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        if editingSpeaker == speaker.id {
                            HStack {
                                let save = {
                                    guard speakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                    else {
                                        return
                                    }

                                    rename(speaker.id, speakerName)
                                    editingSpeaker = nil
                                }
                                TextField("Name", text: $speakerName)
                                    .textFieldStyle(.automatic)
                                    .onSubmit(save)
                                Button("Save", action: save)
                                    .disabled(speakerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                Button("Cancel", systemImage: "xmark") { editingSpeaker = nil }
                                    .labelStyle(.iconOnly)
                                    .help("Cancel renaming")
                            }
                            if speaker.id != "me", let names = meeting.calendarParticipantNames,
                               names.isEmpty == false
                            // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                            {
                                Menu("Choose a Calendar Invitee") {
                                    ForEach(
                                        names,
                                        id: \.self,
                                    ) { name in
                                        Button(name) { speakerName = name }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Text("Click a name to label a voice you recognise. Names apply only to this meeting.")
                .font(.caption)
                .foregroundStyle(.secondary)
            // swiftlint:disable:next closure_body_length - One inline surface.
            DisclosureGroup("More statistics") {
                VStack(
                    alignment: .leading,
                    // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                    spacing: 14,
                    // swiftlint:disable:next closure_body_length - One inline surface.
                ) {
                    if meeting.segments.isEmpty == false {
                        Text("Conversation timeline").font(.headline)
                        Chart(
                            Array(meeting.segments.enumerated()),
                            id: \.offset,
                        ) { _, segment in
                            BarMark(
                                xStart: .value("Start", segment.start),
                                xEnd: .value("End", segment.end),
                                y: .value("Speaker", meeting.name(for: segment.speakerID)),
                            )
                            .foregroundStyle(segment.speakerID == "me" ? Color.teal : .blue)
                            .accessibilityLabel(
                                """
                                \(meeting.name(for: segment.speakerID)), \(durationText(segment.start)) to \
                                \(durationText(segment.end))
                                """
                            )
                        }
                        .chartXScale(domain: 0 ... max(1, meeting.duration))
                        .chartXAxisLabel("Seconds into meeting")
                        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                        .frame(height: CGFloat(max(2, statistics.speakers.count)) * 32 + 40)
                    }
                    HStack(
                        alignment: .top,
                        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                        spacing: 12,
                    ) {
                        MetricView(title: "Meeting duration", value: durationText(meeting.duration))
                        MetricView(title: "Silence", value: durationText(statistics.silence))
                        MetricView(
                            title: "Overlapping speech",
                            value: meeting.hasUnverifiedSpeech ? "Unknown" : durationText(statistics.overlap),
                        )
                    }
                    if meeting.hasUnverifiedSpeech == false {
                        Text(
                            """
                            You spoke for \
                            \((ownStatistics?.meetingShare ?? 0).formatted(.percent.precision(.fractionLength(0)))) \
                            of elapsed meeting time. Speech shares exclude silence and count each voice during \
                            overlap. A turn ends when another voice enters or a pause exceeds 0.75s. Overlap does not \
                            establish who interrupted whom.
                            """
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                }.padding(.top, 8)
            }
        }
    }

    // MARK: Private

    @State private var editingSpeaker: String?
    @State private var speakerName = ""
}
