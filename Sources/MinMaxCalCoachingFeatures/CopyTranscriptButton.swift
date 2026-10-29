import MinMaxCalCoachingDomain
import SwiftUI

struct CopyTranscriptButton: View {
    let meeting: Meeting

    var body: some View {
        Button("Copy Transcript", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(meeting.transcriptText, forType: .string)
        }
        .help("Copy the whole transcript with timestamps and your current speaker names")
    }
}
