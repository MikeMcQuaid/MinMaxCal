import Foundation
import MinMaxCalDomain
import SwiftUI

struct TakeoverEntryView: View {
    // MARK: Internal

    let entry: Takeover.Entry
    let now: Date
    let joinIsPrimary: Bool
    let onJoin: (JoinLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            AgendaRow(item: entry.item, now: now, style: .takeover, onJoin: onJoin, joinIsPrimary: joinIsPrimary)
            ItemDetails(item: entry.item)
        }
    }

    // MARK: Private

    private static let sectionSpacing: CGFloat = 12
}
