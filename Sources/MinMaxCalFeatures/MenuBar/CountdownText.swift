import Foundation
import MinMaxCalDomain
import SwiftUI

public struct CountdownText: View {
    // MARK: Lifecycle

    public init(item: AgendaItem, now: Date) {
        self.item = item
        self.now = now
    }

    // MARK: Public

    public var body: some View {
        Text(Countdown.text(for: item, now: now))
            .monospacedDigit()
    }

    // MARK: Private

    private let item: AgendaItem
    private let now: Date
}
