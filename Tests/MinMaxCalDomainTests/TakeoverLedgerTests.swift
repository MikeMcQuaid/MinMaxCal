import Foundation
import MinMaxCalDomain
import Testing

struct TakeoverLedgerTests {
    @Test
    func `prunes entries older than a day`() {
        let item = Fixtures.reminder("r")
        let takeover = Takeover(entries: [Takeover.Entry(item: item, trigger: .due)], moment: item.start)
        let twoDaysAgo = Fixtures.now.addingTimeInterval(-2 * 24 * 60 * 60)
        let ledger = TakeoverLedger.empty
            .snoozing(takeover, until: Fixtures.now, at: twoDaysAgo)
            .dismissing(takeover, at: Fixtures.now)

        let pruned = ledger.pruned(at: Fixtures.now)

        #expect(pruned.snoozes.isEmpty)
        #expect(pruned.dismissals.count == 1)
    }

    @Test
    func `round trips through JSON`() throws {
        let item = Fixtures.reminder("r")
        let takeover = Takeover(entries: [Takeover.Entry(item: item, trigger: .due)], moment: item.start)
        let ledger = TakeoverLedger.empty.snoozing(
            takeover,
            until: Fixtures.now.addingTimeInterval(300),
            at: Fixtures.now,
        )

        let decoded = try JSONDecoder().decode(TakeoverLedger.self, from: JSONEncoder().encode(ledger))

        #expect(decoded == ledger)
        #expect(decoded.isDismissed(item, trigger: .due, moment: item.start))
    }
}
