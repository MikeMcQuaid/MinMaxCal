import Foundation
import MinMaxCalDomain
import Testing

extension SyncPlannerTests {
    @Test
    func `a newly arrived destination copy blocks creation from an older snapshot`() {
        let link = SyncLink(
            policy: SyncFixtures.policy.id,
            source: SyncFixtures.original.identity,
            destination: "work",
            end: SyncFixtures.original.content.end,
        )
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "arrived", event: "arrived")
        #expect(copy.preventsCreation(for: link, source: SyncFixtures.original) == false)
        copy.content.notes = SyncFixtures.legacy
        #expect(copy.preventsCreation(for: link, source: SyncFixtures.original))
        copy.content.start = copy.content.start.addingTimeInterval(60)
        #expect(copy.preventsCreation(for: link, source: SyncFixtures.original) == false)
        copy.content.notes = SyncMarker.footer(link.id)
        #expect(copy.preventsCreation(for: link, source: SyncFixtures.original))
    }

    @Test
    func `comparison mappings can be discarded when changing pairs but owned copies cannot`() {
        let initial = SyncFixtures.plan(events: [SyncFixtures.original])
        var changed = SyncFixtures.policy
        changed.source = "work"
        changed.destination = "home"
        let comparison = SyncFixtures.plan(events: [SyncFixtures.original], policies: [changed], links: initial.links)
        #expect(comparison.links.isEmpty)
        #expect(comparison.issues.isEmpty)
        let owned = initial.links.map { link in
            var managed = link
            managed.isManaged = true
            return managed
        }
        let managed = SyncFixtures.plan(events: [SyncFixtures.original], policies: [changed], links: owned)
        #expect(managed.links == owned)
        #expect(managed.issues.isEmpty)
    }

    @Test
    func `changing a destination leaves old copies and creates only for the new destination`() throws {
        let initial = SyncFixtures.plan(events: [SyncFixtures.original])
        var link = try #require(initial.links.first)
        link.isManaged = true
        link.copy = SyncIdentity(calendar: "work", item: "copy", event: "copy")
        var copy = try SyncEvent(
            identity: #require(link.copy),
            content: SyncFixtures.original.copyContent(for: SyncFixtures.policy, id: link.id),
        )
        copy.content.title = "Old copy left unchanged"
        var policy = SyncFixtures.policy
        policy.destination = "new"
        var destination = SyncFixtures.calendars[1]
        destination.identifier = "new"
        let plan = SyncPlanner(
            events: [SyncFixtures.original, copy],
            calendars: SyncFixtures.calendars + [destination],
            policies: [policy],
            links: [link],
            interval: SyncFixtures.interval,
        ).plan()
        #expect(plan.issues.isEmpty)
        #expect(plan.links.contains(link))
        #expect(plan.writes.count == 1)
        #expect(plan.writes.first?.action == .create)
        #expect(plan.writes.first?.link.destination == "new")
        let newLink = try #require(plan.links.last)
        let newCopy = SyncEvent(
            identity: SyncIdentity(calendar: "new", item: "new-copy", event: "new-copy"),
            content: SyncFixtures.original.copyContent(for: policy, id: newLink.id),
        )
        let next = SyncPlanner(
            events: [SyncFixtures.original, copy, newCopy],
            calendars: SyncFixtures.calendars + [destination],
            policies: [policy],
            links: plan.links,
            interval: SyncFixtures.interval,
        ).plan()
        #expect(next.writes.isEmpty)
        #expect(next.assessments.map(\.outcome) == [.unchanged])
    }
}
