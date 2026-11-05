import Foundation
import MinMaxCalDomain
import Testing

struct AgendaFilterTests {
    @Test(arguments: ["Out of office", " OUT OF OFFICE \n"])
    func `hides default out of office events before merging`(title: String) {
        let timed = Fixtures.event("timed", title: title)
        let allDay = Fixtures.event("all-day", title: title, isAllDay: true)
        let reminder = Fixtures.reminder("reminder", title: title)
        let meeting = Fixtures.event("meeting", title: "Out of office planning")

        #expect(AgendaFilter.upcoming([timed, allDay, reminder, meeting], now: Fixtures.now) == [reminder, meeting])
    }

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
    func `drops events that only ever had a generic title`() {
        let busy = Fixtures.event("busy", title: "Busy")
        let blank = Fixtures.event("blank", title: " ")
        let real = Fixtures.event("real", title: "Standup")
        let reminder = Fixtures.reminder("reminder", title: "Busy")

        #expect(AgendaFilter.named([busy, blank, real, reminder], rules: .default) == [real, reminder])
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
