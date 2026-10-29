import SwiftUI

struct MeetingHistoryView: View {
    // MARK: Internal

    let model: MeetingModel
    let targetShare: Double
    let turnLimit: Double
    let scroll: ScrollViewProxy

    @Binding var isExpanded: Bool

    var body: some View {
        let meetings = model.history
        if meetings.isEmpty == false {
            Divider()
            DisclosureGroup("Meeting history", isExpanded: $isExpanded) {
                VStack(alignment: .leading) {
                    ForEach(meetings) { meeting in
                        MeetingHistoryRow(
                            model: model,
                            meeting: meeting,
                            targetShare: targetShare,
                            turnLimit: turnLimit,
                            deleting: $deleting,
                        )
                    }
                }
                // swiftlint:disable:next no_magic_numbers - Match agenda details spacing.
                .padding(.top, 8)
            }
            .id("history")
            .onChange(of: deleting) {
                if let deleting {
                    scroll.scrollTo(MeetingHistoryRow.deletionAnchor(deleting), anchor: .bottom)
                }
            }
        }
    }

    // MARK: Private

    @State private var deleting: UUID?
}
