import Foundation
import MinMaxCalDomain
import Testing

struct SyncAssessmentTests {
    @Test
    func `comparison accounts for eligible events and each exclusion without changing the plan`() {
        let original = SyncFixtures.original
        var free = original
        free.identity = SyncIdentity(calendar: "home", item: "free", event: "free")
        free.content.availability = .free
        var unknown = free
        unknown.identity = SyncIdentity(calendar: "home", item: "unknown", event: "unknown")
        unknown.content.availability = .unknown
        var allDay = original
        allDay.identity = SyncIdentity(calendar: "home", item: "all-day", event: "all-day")
        allDay.content.isAllDay = true
        var pending = original
        pending.identity = SyncIdentity(calendar: "home", item: "pending", event: "pending")
        pending.response = .pending
        var declined = original
        declined.identity = SyncIdentity(calendar: "home", item: "declined", event: "declined")
        declined.response = .declined
        var cancelled = original
        cancelled.identity = SyncIdentity(calendar: "home", item: "cancelled", event: "cancelled")
        cancelled.isCancelled = true
        var copy = original
        copy.identity = SyncIdentity(calendar: "home", item: "copy", event: "copy")
        copy.content.notes = SyncFixtures.legacy
        var policy = SyncFixtures.policy
        policy.allDay = .exclude
        let plan = SyncFixtures.plan(
            events: [original, free, unknown, allDay, pending, declined, cancelled, copy],
            policies: [policy],
        )
        #expect(plan.checkedPolicies == [SyncFixtures.policy.id])
        #expect(plan.assessments.count == 8)
        #expect(plan.assessments.count(where: { $0.outcome.isEligible }) == 2)
        #expect(plan.assessments.map(\.outcome) == [
            .create, .notBusy, .create, .allDay, .unanswered, .declined, .cancelled, .copy,
        ])
        #expect(plan.writes.count == 2)
        #expect(plan.noChangeCount() == 6)
        #expect(plan.noChangeCount(for: SyncFixtures.policy.id) == 6)
        #expect(plan.noChangeCount(for: UUID()) == 0)
    }

    @Test
    func `an empty checked calendar is different from a pair that could not be checked`() {
        let empty = SyncFixtures.plan(events: [])
        #expect(empty.checkedPolicies == [SyncFixtures.policy.id])
        #expect(empty.assessments.isEmpty)
        let missing = SyncPlanner(
            events: [], calendars: [], policies: [SyncFixtures.policy], links: [], interval: SyncFixtures.interval,
        ).plan()
        #expect(missing.checkedPolicies.isEmpty)
        #expect(missing.issues.isEmpty == false)
    }

    @Test
    func `matching distinguishes legacy adoption from missing and unchanged copies`() throws {
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "copy", event: "copy")
        copy.content.notes = SyncFixtures.legacy
        let adoption = SyncFixtures.plan(events: [SyncFixtures.original, copy])
        #expect(adoption.assessments.map(\.outcome) == [.adopt])
        #expect(adoption.writes.map(\.action) == [.adopt])
        #expect(adoption.noChangeCount() == 0)
        #expect(adoption.writes.first?.reasons.contains(where: { $0.contains("existing copy") }) == true)
        let link = try #require(adoption.links.first)
        copy.content = SyncFixtures.original.copyContent(for: SyncFixtures.policy, id: link.id)
        let matched = SyncFixtures.plan(events: [SyncFixtures.original, copy], links: adoption.links)
        #expect(matched.assessments.map(\.outcome) == [.unchanged])
        #expect(matched.writes.isEmpty)
        #expect(matched.noChangeCount() == 1)
        copy.content.title = "Changed copy"
        let changed = SyncFixtures.plan(events: [SyncFixtures.original, copy], links: adoption.links)
        #expect(changed.assessments.map(\.outcome) == [.update])
        #expect(changed.writes.map(\.action) == [.update])
    }

    @Test
    func `ambiguous migration and missing copies are not reported as matched`() {
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "copy", event: "copy")
        copy.content.notes = SyncFixtures.legacy
        var duplicate = copy
        duplicate.identity = SyncIdentity(calendar: "work", item: "duplicate", event: "duplicate")
        let ambiguous = SyncFixtures.plan(events: [SyncFixtures.original, copy, duplicate])
        #expect(ambiguous.assessments.map(\.outcome) == [.blocked])
        #expect(ambiguous.unresolved.count == 2)
        #expect(ambiguous.noChangeCount() == 0)
        let adopted = SyncFixtures.plan(events: [SyncFixtures.original, copy])
        let missing = SyncFixtures.plan(events: [SyncFixtures.original], links: adopted.links)
        #expect(missing.assessments.map(\.outcome) == [.waiting])
        #expect(missing.writes.isEmpty)
        #expect(missing.noChangeCount() == 0)
    }

    @Test
    func `native invitations explain why no copy is proposed`() {
        var original = SyncFixtures.original
        original.identity.external = "invitation"
        var invitation = original
        invitation.identity = SyncIdentity(calendar: "work", item: "invite", event: "invite", external: "invitation")
        let plan = SyncFixtures.plan(events: [original, invitation])
        #expect(plan.assessments.map(\.outcome) == [.invitation])
        #expect(plan.writes.isEmpty)
        #expect(plan.noChangeCount() == 1)
    }
}
