import Foundation
import MinMaxCalDomain
import Testing

struct AgendaSyncTests {
    @Test
    func `tracked copies follow their original even when their title and timing have drifted`() throws {
        let original = Fixtures.event("original", title: "Flight", calendar: Fixtures.home, isAccepted: false)
        var copy = Fixtures.event("copy", title: "Travel", startingIn: 10)
        let link = try SyncLink(
            policy: UUID(),
            source: SyncIdentity(
                calendar: "home",
                item: "original",
                event: "original",
            ),
            destination: "work",
            end: #require(original.end),
            copy: SyncIdentity(
                calendar: "work",
                item: "copy",
                event: "copy",
            ),
        )
        copy.notes = SyncMarker.footer(link.id)
        let merged = AgendaMerger.merge([copy, original], rules: .default, syncLinks: [link])
        #expect(merged.count == 1)
        #expect(merged.first?.title == original.title)
        #expect(merged.first?.start == original.start)
        #expect(merged.first?.isAccepted == false)
        #expect(merged.first?.members.count == 2)
    }

    @Test
    func `a saved footer reconnects a copy whose local identifier changed`() throws {
        let original = Fixtures.event("original", title: "Flight", calendar: Fixtures.home)
        var copy = Fixtures.event("new-id", title: "Travel")
        let link = try SyncLink(
            policy: UUID(),
            source: SyncIdentity(
                calendar: "home",
                item: "original",
                event: "original",
            ),
            destination: "work",
            end: #require(original.end),
        )
        copy.notes = SyncMarker.footer(link.id)
        #expect(AgendaMerger.merge([original, copy], rules: .default, syncLinks: [link]).count == 1)
    }
}
