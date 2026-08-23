import Foundation
import MinMaxCalDomain
import SwiftUI

struct TakeoverEntryView: View {
    // MARK: Internal

    let entry: Takeover.Entry
    let joinIsPrimary: Bool
    let rules: MatchingRules
    let onJoin: (JoinLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            AgendaRow(item: entry.item, style: .takeover, onJoin: onJoin, joinIsPrimary: joinIsPrimary)
            ItemDetails(item: entry.item, rules: rules)
        }
    }

    // MARK: Private

    private static let sectionSpacing: CGFloat = 12
}
