import Foundation
import MinMaxCalDomain
import Testing

struct SyncPlannerTests {
    @Test
    func `starts disabled and creates a private busy copy only when a rule is enabled`() throws {
        #expect(SyncSettings().mode == .off)
        #expect(SyncPolicy().isEnabled == false)
        var disabled = SyncFixtures.policy
        disabled.isEnabled = false
        #expect(SyncFixtures.plan(events: [SyncFixtures.original], policies: [disabled]).writes.isEmpty)
        let result = SyncFixtures.plan(events: [SyncFixtures.original])
        let write = try #require(result.writes.first)
        guard case let .save(link, source, target, content) = write else {
            Issue.record("Expected a new copy")
            return
        }

        #expect(source == SyncFixtures.original)
        #expect(target == nil)
        #expect(content.title == "Busy")
        #expect(content.location == nil)
        #expect(content.url == nil)
        #expect(content.notes == SyncMarker.footer(link.id))
        #expect(result.links.count == 1)
    }

    @Test
    func `preserves title location and links without copying private notes`() throws {
        var details = SyncFixtures.policy
        details.content = .original
        let write = try #require(SyncFixtures.plan(events: [SyncFixtures.original], policies: [details]).writes.first)
        guard case let .save(_, _, _, content) = write else {
            Issue.record("Expected a copy")
            return
        }

        #expect(content.title == SyncFixtures.original.content.title)
        #expect(content.location == SyncFixtures.original.content.location)
        #expect(content.notes?.contains("https://meet.google.com/abc-defg-hij") == true)
        #expect(content.notes?.contains("Secret") == false)
    }

    @Test
    func `busy only skips explicit nonbusy availability even for all day travel`() {
        var travel = SyncFixtures.policy
        travel.content = .travel
        travel.allDay = .all
        for availability in [SyncContent.Availability.free, .tentative, .unavailable] {
            var event = SyncFixtures.original
            event.content.isAllDay = true
            event.content.availability = availability
            #expect(SyncFixtures.plan(events: [event], policies: [travel]).writes.isEmpty)
        }
        var busy = SyncFixtures.original
        busy.content.isAllDay = true
        #expect(SyncFixtures.plan(events: [busy], policies: [travel]).writes.count == 1)
    }

    @Test
    func `adopts a uniquely matched legacy copy but never a coincident ordinary event`() throws {
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "legacy", event: "legacy")
        copy.content.title = "Busy"
        copy.content.notes = SyncFixtures.legacy
        let result = SyncFixtures.plan(events: [SyncFixtures.original, copy])
        #expect(result.unresolved.isEmpty)
        #expect(result.links.first?.copy == copy.identity)
        guard case let .save(_, _, target, _) = try #require(result.writes.first) else {
            Issue.record("Expected adoption")
            return
        }

        #expect(target == copy)
        copy.content.notes = "Unrelated appointment"
        #expect(SyncFixtures.plan(events: [SyncFixtures.original, copy]).links.first?.copy == nil)
    }

    @Test
    func `ambiguous legacy blocks suppress duplicate creation`() {
        var another = SyncFixtures.original
        another.identity.item = "another"
        another.identity.event = "another"
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "legacy", event: "legacy")
        copy.content.notes = SyncFixtures.legacy
        copy.content.title = "Busy"
        let result = SyncFixtures.plan(events: [SyncFixtures.original, another, copy])
        #expect(result.writes.isEmpty)
        #expect(result.unresolved.count == 1)
    }

    @Test
    func `repeated reconciliation is quiet and mirrored copies never become sources`() throws {
        let first = SyncFixtures.plan(events: [SyncFixtures.original])
        guard case let .save(link, _, _, content) = try #require(first.writes.first) else {
            Issue.record("Expected a copy")
            return
        }

        let copy = SyncEvent(identity: SyncIdentity(calendar: "work", item: "copy", event: "copy"), content: content)
        var stored = link
        stored.copy = copy.identity
        let reverse = SyncPolicy(source: "work", destination: "home", isEnabled: true)
        let result = SyncFixtures.plan(
            events: [SyncFixtures.original, copy],
            policies: [SyncFixtures.policy, reverse],
            links: [stored],
        )
        #expect(result.writes.isEmpty)
        #expect(result.links.count == 1)
        var edited = copy
        edited.content.notes = nil
        let missingFooter = SyncFixtures.plan(
            events: [SyncFixtures.original, edited], policies: [SyncFixtures.policy, reverse], links: [stored],
        )
        #expect(missingFooter.writes.isEmpty)
    }

    @Test
    func `waits for a second observation before deleting a missing source and pauses for missing calendars`(
    ) throws {
        var link = SyncLink(
            policy: SyncFixtures.policy.id,
            source: SyncFixtures.original.identity,
            destination: "work",
            end: SyncFixtures.original.content.end,
        )
        let copy = SyncEvent(
            identity: SyncIdentity(calendar: "work", item: "copy", event: "copy"),
            content: SyncFixtures.original.copyContent(for: SyncFixtures.policy, id: link.id),
        )
        link.copy = copy.identity
        let first = SyncFixtures.plan(events: [copy], links: [link])
        #expect(first.writes.isEmpty)
        #expect(first.links.first?.missingSince == Fixtures.now)
        let later = DateInterval(start: Fixtures.now.addingTimeInterval(120), end: SyncFixtures.interval.end)
        let second = SyncPlanner(
            events: [copy],
            calendars: SyncFixtures.calendars,
            policies: [SyncFixtures.policy],
            links: first.links,
            interval: later,
        ).plan()
        guard case .remove = try #require(second.writes.first) else {
            Issue.record("Expected removal")
            return
        }

        #expect(second.writes.first?.reasons == [
            "The original is still missing after a second check at least a minute later."
        ])
        #expect(second.noChangeCount() == 0)

        let unavailable = SyncPlanner(
            events: [copy],
            calendars: [SyncFixtures.calendars[1]],
            policies: [SyncFixtures.policy],
            links: first.links,
            interval: later,
        ).plan()
        #expect(unavailable.writes.isEmpty)
        #expect(unavailable.issues.isEmpty == false)
    }

    @Test
    func `does not copy an invitation already present on the destination`() {
        var source = SyncFixtures.original
        source.identity.external = "invitation"
        var destination = source
        destination.identity = SyncIdentity(
            calendar: "work",
            item: "invite-copy",
            event: "invite-copy",
            external: "invitation",
        )
        #expect(SyncFixtures.plan(events: [source, destination]).writes.isEmpty)
    }

    @Test
    func `comparison links a legacy copy arriving after the initial check`() throws {
        let initial = SyncFixtures.plan(events: [SyncFixtures.original])
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "legacy", event: "legacy")
        copy.content.notes = SyncFixtures.legacy
        let later = SyncFixtures.plan(events: [SyncFixtures.original, copy], links: initial.links)
        #expect(later.links.first?.copy == copy.identity)
        guard case let .save(_, _, target, _) = try #require(later.writes.first) else {
            Issue.record("Expected adoption")
            return
        }

        #expect(target == copy)
    }

    @Test
    func `a pending copy never bypasses ambiguous migration checks`() {
        let initial = SyncFixtures.plan(events: [SyncFixtures.original])
        var copy = SyncFixtures.original
        copy.identity = SyncIdentity(calendar: "work", item: "legacy", event: "legacy")
        copy.content.notes = SyncFixtures.legacy
        var another = SyncFixtures.original
        another.identity.item = "another"
        let later = SyncFixtures.plan(events: [SyncFixtures.original, another, copy], links: initial.links)
        #expect(later.writes.isEmpty)
        #expect(later.unresolved == [copy])
    }

    @Test
    func `two source calendars carrying the same invitation propose only one destination copy`() {
        var first = SyncFixtures.original
        first.identity.external = "shared"
        var second = first
        second.identity.calendar = "team"
        second.identity.item = "second"
        var team = SyncFixtures.calendars[0]
        team.identifier = "team"
        let result = SyncPlanner(
            events: [first, second],
            calendars: SyncFixtures.calendars + [team],
            policies: [SyncFixtures.policy, SyncPolicy(source: "team", destination: "work", isEnabled: true)],
            links: [],
            interval: SyncFixtures.interval,
        ).plan()
        #expect(result.writes.count == 1)
    }

    @Test(arguments: [false, true], [SyncPolicy.AllDay.busy, .all])
    func `missing availability defaults to Busy for filtering and copying`(
        isAllDay: Bool, allDay: SyncPolicy.AllDay,
    ) throws {
        var source = SyncFixtures.original
        source.content.availability = .unknown
        source.content.isAllDay = isAllDay
        var include = SyncFixtures.policy
        include.allDay = allDay
        guard case let .save(
            _,
            _,
            _,
            content,
        ) = try #require(SyncFixtures.plan(events: [source], policies: [include]).writes.first)
        else {
            Issue.record("Expected copy")
            return
        }

        #expect(content.availability == .busy)
        #expect(source.content.availability == .unknown)
        include.allDay = .exclude
        if isAllDay {
            #expect(SyncFixtures.plan(events: [source], policies: [include]).writes.isEmpty)
        }
    }
}
