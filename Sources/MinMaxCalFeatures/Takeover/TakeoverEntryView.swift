import Foundation
import MinMaxCalAgenda
import MinMaxCalDomain
import SwiftUI

struct TakeoverEntryView: View {
    // MARK: Internal

    let entry: Takeover.Entry
    let joinIsPrimary: Bool
    let rules: MatchingRules
    let onJoin: (JoinLink) -> Void
    let onJoinAndRecord: (() -> Void)?
    let recordingReady: Bool
    let recordsJoinsByDefault: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            AgendaRow(
                item: entry.item,
                style: .takeover,
                onJoin: onJoinAndRecord == nil ? onJoin : nil,
                joinIsPrimary: joinIsPrimary,
            )
            ItemDetails(item: entry.item, rules: rules, showsAttendees: true)
            if let link = entry.item.joinLink, let onJoinAndRecord {
                HStack {
                    Spacer()
                    ForEach([recordsJoinsByDefault == false, recordsJoinsByDefault], id: \.self) { recording in
                        JoinButton(
                            link: link,
                            isPrimary: joinIsPrimary && recording == recordsJoinsByDefault,
                            recordsMeeting: recording,
                            title: recording ? "Join and Record" : "Join",
                        ) { link in
                            if recording {
                                onJoinAndRecord()
                            } else {
                                onJoin(link)
                            }
                        }
                        .disabled(recording && recordingReady == false)
                        .help(recording ? "Join and record this meeting" : "Join without recording")
                        .accessibilityHint(recording && recordingReady == false
                            ? "Download speech models in Settings → Coaching before recording." : "")
                    }
                }
            }
        }
    }

    // MARK: Private

    private static let sectionSpacing: CGFloat = 12
}
