import Foundation
import MinMaxCalDomain
import Testing

struct AgendaMergerTests {
    // MARK: Internal

    @Test
    func `merges copies sharing an invite identifier`() {
        let work = Fixtures.event("work", title: "Quarterly review", invite: "uid-1", calendar: Fixtures.work)
        var team = Fixtures.event(
            "team",
            title: "Quarterly review",
            invite: "uid-1",
            startingIn: 35,
            calendar: Fixtures.team,
        )
        team.location = "Boardroom"

        let merged = AgendaMerger.merge([work, team], rules: rules)

        #expect(merged.count == 1)
        #expect(merged[0].members == work.members + team.members)
        #expect(merged[0].calendars == [Fixtures.work, Fixtures.team])
        #expect(merged[0].location == "Boardroom")
    }

    @Test
    func `merges generic titles at the same time`() {
        let invitation = Fixtures.event("invite", title: "Quarterly review", invite: "uid-1")
        let busy = Fixtures.event("busy", title: "Busy", calendar: Fixtures.home)
        let blank = Fixtures.event("blank", title: "  ", calendar: Fixtures.team)

        let merged = AgendaMerger.merge([busy, invitation, blank], rules: rules)

        #expect(merged.count == 1)
        #expect(merged[0].title == "Quarterly review")
        #expect(merged[0].calendars == [Fixtures.home, Fixtures.work, Fixtures.team])
    }

    @Test
    func `merges matching titles at the same time ignoring case and whitespace`() {
        let one = Fixtures.event("one", title: "Standup")
        let two = Fixtures.event("two", title: " standup ", calendar: Fixtures.team)
        #expect(AgendaMerger.merge([one, two], rules: rules).count == 1)
    }

    @Test
    func `keeps different meetings at the same time apart`() {
        let one = Fixtures.event("one", title: "Standup")
        let two = Fixtures.event("two", title: "Dentist", calendar: Fixtures.home)
        let busy = Fixtures.event("busy", title: "Busy", calendar: Fixtures.team)

        let merged = AgendaMerger.merge([one, two, busy], rules: rules)

        #expect(merged.map(\.title) == ["Standup", "Dentist"])
        #expect(merged[0].calendars == [Fixtures.work, Fixtures.team])
    }

    @Test
    func `splits an invite group with two specific titles`() {
        let one = Fixtures.event("one", title: "Planning", invite: "uid")
        let two = Fixtures.event("two", title: "Planning (copy)", invite: "uid", startingIn: 60)
        let busy = Fixtures.event("busy", title: "Busy", invite: "uid", startingIn: 60)

        let merged = AgendaMerger.merge([one, two, busy], rules: rules)

        #expect(merged.map(\.title) == ["Planning", "Planning (copy)"])
        #expect(merged[0].members == one.members + busy.members)
    }

    @Test
    func `acceptance and response follow any accepted member`() {
        let pending = Fixtures.event(
            "pending",
            title: "Planning",
            invite: "uid",
            attendees: [Attendee(name: "Me", response: .pending, isCurrentUser: true)],
            isAccepted: false,
        )
        let accepted = Fixtures.event(
            "accepted",
            title: "Planning",
            invite: "uid",
            calendar: Fixtures.team,
            attendees: [Attendee(name: "Me", response: .accepted, isCurrentUser: true)],
        )

        let merged = AgendaMerger.merge([pending, accepted], rules: rules)

        #expect(merged[0].isAccepted)
        #expect(merged[0].currentUserResponse == .accepted)
        #expect(merged[0].attendees == pending.attendees)
    }

    @Test
    func `generic members never speak for the invitation`() {
        let invitation = Fixtures.event(
            "invite",
            title: "Planning",
            attendees: [Attendee(name: "Me", response: .pending, isCurrentUser: true)],
            isAccepted: false,
        )
        let busy = Fixtures.event("busy", title: "Busy", calendar: Fixtures.home)

        let merged = AgendaMerger.merge([busy, invitation], rules: rules)

        #expect(merged.count == 1)
        #expect(merged[0].isAccepted == false)
        #expect(merged[0].currentUserResponse == .pending)
        #expect(merged[0].attendees == invitation.attendees)
    }

    @Test
    func `never merges reminders`() {
        let one = Fixtures.reminder("one", title: "Busy")
        let two = Fixtures.reminder("two", title: "Busy")
        #expect(AgendaMerger.merge([one, two], rules: rules).count == 2)
    }

    // MARK: Private

    private let rules: MatchingRules = .default
}
