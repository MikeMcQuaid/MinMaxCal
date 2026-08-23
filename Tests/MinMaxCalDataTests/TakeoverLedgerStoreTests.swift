import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Testing

struct TakeoverLedgerStoreTests {
    // MARK: Internal

    @Test
    func `loads empty when there is no file`() {
        let store = TakeoverLedgerStore(file: TestScratch.directory().appending(path: "takeovers.json"))
        #expect(store.load() == .empty)
    }

    @Test
    func `saves pruned and reloads`() {
        let store = TakeoverLedgerStore(file: TestScratch.directory().appending(path: "nested/takeovers.json"))
        let item = AgendaItem(
            members: [MemberIdentity(calendarItemIdentifier: "r")],
            kind: .reminder,
            title: "R",
            start: now,
        )
        let takeover = Takeover(entries: [Takeover.Entry(item: item, trigger: .due)], moment: now)
        let stale = TakeoverLedger.empty.dismissing(takeover, at: now.addingTimeInterval(-2 * 24 * 60 * 60))
        let fresh = stale.snoozing(takeover, until: now.addingTimeInterval(300), at: now)

        store.save(fresh, at: now)
        let loaded = store.load()

        #expect(loaded.snoozes.count == 1)
        #expect(loaded.dismissals.count == 1)
        #expect(loaded.dismissals.allSatisfy { $0.recordedAt == now })
    }

    // MARK: Private

    private let now: Date = .init(timeIntervalSinceReferenceDate: 800_000_040)
}
