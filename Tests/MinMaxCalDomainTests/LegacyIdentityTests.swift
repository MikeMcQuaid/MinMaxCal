import Foundation
import MinMaxCalDomain
import Testing

struct LegacyIdentityTests {
    @Test
    func `recognised legacy identifiers recover the original UID`() {
        #expect(SyncMarker.legacySourceIdentifier(in: SyncFixtures.legacyFirstUID) == "source-one")
        #expect(SyncMarker.legacySourceIdentifier(in: SyncFixtures.legacySecondUID) == "source-two")
        #expect(SyncMarker.legacySourceIdentifier(in: nil) == nil)
        #expect(SyncMarker.legacySourceIdentifier(in: "broken@google.com") == nil)
        #expect(SyncMarker.legacySourceIdentifier(in: SyncFixtures.legacyFirstUID + ".example.com") == nil)
        #expect(SyncMarker.legacySourceIdentifier(in: SyncFixtures.legacyFirstUID.replacing("8@", with: "9@")) == nil)
    }

    @Test
    func `original UIDs distinguish two legacy copies at the same time`() {
        var first = SyncFixtures.original
        first.identity.external = "source-one"
        var second = first
        second.identity = SyncIdentity(calendar: "home", item: "second", event: "second", external: "source-two")
        var firstCopy = first
        firstCopy.identity = SyncIdentity(
            calendar: "work", item: "first-copy", event: "first-copy", external: SyncFixtures.legacyFirstUID,
        )
        firstCopy.content.notes = SyncFixtures.legacy
        var secondCopy = firstCopy
        secondCopy.identity = SyncIdentity(
            calendar: "work", item: "second-copy", event: "second-copy", external: SyncFixtures.legacySecondUID,
        )
        let plan = SyncFixtures.plan(events: [first, second, secondCopy, firstCopy])
        #expect(plan.writes.map(\.action) == [.adopt, .adopt])
        #expect(plan.links.first { $0.source == first.identity }?.copy == firstCopy.identity)
        #expect(plan.links.first { $0.source == second.identity }?.copy == secondCopy.identity)
        #expect(plan.unresolved.isEmpty)
    }

    @Test(arguments: ["different UID", "different occurrence", "different time", "duplicate copy"])
    func `recognised tracking still rejects conflicting migration candidates`(conflict: String) {
        var original = SyncFixtures.original
        original.identity.external = conflict == "different UID" ? "source-two" : "source-one"
        if conflict == "different occurrence" {
            original.identity.occurrence = original.content.start
        }
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(
            calendar: "work", item: "copy", event: "copy", external: SyncFixtures.legacyFirstUID,
        )
        copy.content.notes = SyncFixtures.legacy
        if conflict == "different time" {
            copy.content.start.addTimeInterval(60)
        }
        var events = [original, copy]
        if conflict == "duplicate copy" {
            copy.identity.item = "duplicate"
            events.append(copy)
        }
        let plan = SyncFixtures.plan(events: events)
        #expect(plan.writes.contains { $0.action == .adopt } == false)
        #expect(plan.links.allSatisfy { $0.copy == nil })
        if conflict != "different time" {
            #expect(plan.writes.isEmpty)
        }
    }
}
