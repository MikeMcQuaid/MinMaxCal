import MinMaxCalDomain
import Testing

struct SyncEligibilityTests {
    @Test(arguments: [false, true])
    func `events without a personal RSVP can be copied even when they list attendees`(hasAttendees: Bool) {
        var event = SyncFixtures.original
        event.isAccepted = false
        event.hasAttendees = hasAttendees
        let plan = SyncFixtures.plan(events: [event])
        #expect(plan.writes.map(\.action) == [.create])
        #expect(plan.assessments.map(\.outcome) == [.create])
    }

    @Test(arguments: [AttendeeResponse.pending, .declined, .unknown])
    func `an invitation with an explicit unaccepted personal RSVP is still skipped`(response: AttendeeResponse) {
        var event = SyncFixtures.original
        event.hasAttendees = true
        event.isAccepted = false
        event.response = response
        let plan = SyncFixtures.plan(events: [event])
        #expect(plan.writes.isEmpty)
        #expect(plan.assessments.allSatisfy { $0.outcome.isEligible == false })
    }

    @Test(arguments: [AttendeeResponse.accepted, .tentative])
    func `accepted and tentative invitations are still copied`(response: AttendeeResponse) {
        var event = SyncFixtures.original
        event.hasAttendees = true
        event.isAccepted = response == .accepted
        event.response = response
        #expect(SyncFixtures.plan(events: [event]).writes.map(\.action) == [.create])
    }
}
