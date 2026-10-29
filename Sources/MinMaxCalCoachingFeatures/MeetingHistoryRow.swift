import MinMaxCalCoachingDomain
import SwiftUI

struct MeetingHistoryRow: View {
    // MARK: Internal

    let model: MeetingModel
    let meeting: Meeting
    let targetShare: Double
    let turnLimit: Double

    @Binding var deleting: UUID?

    var body: some View {
        // swiftlint:disable:next closure_body_length - One inline history row.
        VStack(alignment: .leading) {
            HStack {
                Button(action: toggle) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            MeetingTitleView(meeting: meeting)
                            if meeting.isComplete == false {
                                Text("Partial summary").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .modifier(CoachingRow(
                    label: meeting.title,
                    hint: isExpanded ? "Hides the details" : "Shows the details",
                    action: toggle,
                ))
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                CopyTranscriptButton(meeting: meeting)
                    .labelStyle(.iconOnly)
                    .disabled(meeting.transcriptTurns.isEmpty)
                Button("Delete Summary", systemImage: "trash", role: .destructive) { deleting = meeting.id }
                    .labelStyle(.iconOnly)
                    .help("Delete this summary")
            }
            if deleting == meeting.id {
                HStack {
                    Text("Delete this meeting?").font(.caption)
                    Spacer()
                    Button("Cancel") { deleting = nil }.keyboardShortcut(.cancelAction)
                    Button("Delete", role: .destructive) {
                        Task {
                            await model.delete(meeting)
                        }
                        deleting = nil
                    }
                }
                .id(Self.deletionAnchor(meeting.id))
            }
            if isExpanded {
                MeetingDetailsView(model: model, meeting: meeting, targetShare: targetShare, turnLimit: turnLimit)
            }
        }
        .accessibilityElement(children: .contain)
    }

    static func deletionAnchor(_ id: UUID) -> String {
        "delete-\(id)"
    }

    // MARK: Private

    private var isExpanded: Bool {
        model.selectedID == meeting.id
    }

    private func toggle() {
        deleting = nil
        model.selectedID = isExpanded ? nil : meeting.id
    }
}
