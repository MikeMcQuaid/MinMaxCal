import MinMaxCalCoachingDomain
import SwiftUI

struct MeetingTitleView: View {
    let meeting: Meeting

    var body: some View {
        // swiftlint:disable:next no_magic_numbers - Match the agenda's compact headings.
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title)
                .font(.headline)
                // swiftlint:disable:next no_magic_numbers - Keep the history row narrow.
                .lineLimit(2)
            Text(meeting.startedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
