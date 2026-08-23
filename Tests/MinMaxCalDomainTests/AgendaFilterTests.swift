import Foundation
import MinMaxCalDomain
import Testing

struct AgendaFilterTests {
    @Test
    func `drops past cancelled declined and completed items`() {
        var cancelled = Fixtures.event("cancelled")
        cancelled.isCancelled = true
        var completed = Fixtures.reminder("completed")
        completed.isCompleted = true
        let declined = Fixtures.event(
            "declined",
            attendees: [Attendee(name: "Me", response: .declined, isCurrentUser: true)],
        )
        let past = Fixtures.event("past", startingIn: -60, duration: 30)
        let upcoming = Fixtures.event("upcoming")
        let inProgress = Fixtures.event("in-progress", startingIn: -10, duration: 30)
        let overdue = Fixtures.reminder("overdue", dueIn: -120)

        let kept = AgendaFilter.upcoming(
            [cancelled, completed, declined, past, upcoming, inProgress, overdue],
            now: Fixtures.now,
        )

        #expect(kept == [upcoming, inProgress, overdue])
    }

    @Test
    func `keeps pending and tentative invitations`() {
        let pending = Fixtures.event(
            "pending",
            attendees: [Attendee(name: "Me", response: .pending, isCurrentUser: true)],
        )
        let tentative = Fixtures.event(
            "tentative",
            attendees: [Attendee(name: "Me", response: .tentative, isCurrentUser: true)],
        )
        #expect(AgendaFilter.upcoming([pending, tentative], now: Fixtures.now) == [pending, tentative])
    }
}
