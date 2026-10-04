import Foundation
import MinMaxCalDomain
import Testing

struct SyncWriteTests {
    @Test
    func `new copies explain why they are needed`() throws {
        let write = try #require(SyncFixtures.plan(events: [SyncFixtures.original]).writes.first)
        #expect(write.reasons == ["The original matches this pair’s rules and has no matching copy."])
    }

    @Test(arguments: ["title", "time", "all-day", "availability", "time zone", "location", "link", "notes", "alarms"])
    func `every field difference explains an update`(field: String) throws {
        let initial = SyncFixtures.plan(events: [SyncFixtures.original])
        let link = try #require(initial.links.first)
        var copy = SyncEvent(
            identity: SyncIdentity(calendar: "work", item: "copy", event: "copy"),
            content: SyncFixtures.original.copyContent(for: SyncFixtures.policy, id: link.id),
        )
        switch field {
        case "title":
            copy.content.title = "Changed title"

        case "time":
            copy.content.start.addTimeInterval(60)

        case "all-day":
            copy.content.isAllDay = true

        case "availability":
            copy.content.availability = .free

        case "time zone":
            copy.content.timeZone = "Europe/London"

        case "location":
            copy.content.location = "Changed location"

        case "link":
            copy.content.url = URL(string: "https://example.com")

        case "notes":
            copy.content.notes = "Extra notes\n" + (copy.content.notes ?? "")

        default:
            copy.hasAlarms = true
        }
        let plan = SyncFixtures.plan(events: [SyncFixtures.original, copy], links: initial.links)
        let write = try #require(plan.writes.first)
        #expect(write.action == .update)
        #expect(write.reasons.count == 1)
        #expect(write.reasons.first?.lowercased().contains(field) == true)
        #expect(plan.noChangeCount() == 0)
    }

    @Test
    func `a skipped original with a copy counts as a removal not as no changes`() throws {
        let initial = SyncFixtures.plan(events: [SyncFixtures.original])
        let link = try #require(initial.links.first)
        let copy = SyncEvent(
            identity: SyncIdentity(calendar: "work", item: "copy", event: "copy"),
            content: SyncFixtures.original.copyContent(for: SyncFixtures.policy, id: link.id),
        )
        var original = SyncFixtures.original
        original.content.availability = .free
        let plan = SyncFixtures.plan(events: [original, copy], links: initial.links)
        #expect(plan.assessments.map(\.outcome) == [.notBusy])
        let write = try #require(plan.writes.first)
        #expect(write.action == .remove)
        #expect(write
            .reasons == ["The original is marked Free, Tentative or Unavailable; this pair only copies Busy events."])
        #expect(plan.noChangeCount() == 0)
        #expect(plan.noChangeCount(for: SyncFixtures.policy.id) == 0)
    }
}
