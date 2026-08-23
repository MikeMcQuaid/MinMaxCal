import Foundation
import MinMaxCalDomain
import Testing

struct TakeoverPlannerTests {
    // MARK: Internal

    @Test
    func `picks the earliest accepted timed item`() {
        let allDay = Fixtures.event("all-day", startingIn: -60, duration: 600, isAllDay: true)
        let pending = Fixtures.event("pending", startingIn: 5, isAccepted: false)
        let accepted = Fixtures.event("accepted", startingIn: 10)
        let reminder = Fixtures.reminder("reminder", dueIn: 20)

        let takeover = next([allDay, pending, accepted, reminder])

        #expect(takeover?.entries.map(\.item.title) == [accepted.title])
        #expect(takeover?.entries.first?.trigger == .start)
        #expect(takeover?.moment == accepted.start)
    }

    @Test
    func `groups items due in the same minute`() {
        let event = Fixtures.event("event", startingIn: 10)
        let reminder = Fixtures.reminder("reminder", dueIn: 10.5)
        let takeover = next([event, reminder])
        #expect(takeover?.entries.map(\.trigger) == [.start, .due])
    }

    @Test
    func `shows recent moments but skips older ones`() {
        let recent = Fixtures.event("recent", startingIn: -9)
        let old = Fixtures.event("old", startingIn: -11, duration: 60)
        #expect(next([old, recent])?.entries.first?.item == recent)
        #expect(next([old]) == nil)
    }

    @Test
    func `honours the switches`() {
        let event = Fixtures.event("event", startingIn: 10)
        let reminder = Fixtures.reminder("reminder", dueIn: 5)
        let eventsOnly = TakeoverSettings(onEventStart: true, onReminderDue: false, snoozeMinutes: [])
        let nothing = TakeoverSettings(onEventStart: false, onReminderDue: false, snoozeMinutes: [])
        #expect(next([event, reminder], settings: eventsOnly)?.entries.first?.item == event)
        #expect(next([event, reminder], settings: nothing) == nil)
    }

    @Test
    func `skips dismissed takeovers and returns at the snooze time`() throws {
        let reminder = Fixtures.reminder("reminder", dueIn: -1)
        let first = try #require(next([reminder]))
        #expect(first.entries.first?.trigger == .due)

        let dismissed = TakeoverLedger.empty.dismissing(first, at: Fixtures.now)
        #expect(next([reminder], ledger: dismissed) == nil)

        let snoozeTime = Fixtures.now.addingTimeInterval(5 * 60)
        let snoozed = TakeoverLedger.empty.snoozing(first, until: snoozeTime, at: Fixtures.now)
        let second = try #require(next([reminder], ledger: snoozed))
        #expect(second.entries.first?.trigger == .snooze)
        #expect(second.moment == snoozeTime)

        let both = snoozed.dismissing(second, at: Fixtures.now)
        #expect(next([reminder], ledger: both) == nil)
    }

    @Test
    func `a snoozed reminder can be snoozed again`() throws {
        let reminder = Fixtures.reminder("reminder", dueIn: -1)
        let first = try #require(next([reminder]))
        let firstSnooze = Fixtures.now.addingTimeInterval(5 * 60)
        let once = TakeoverLedger.empty.snoozing(first, until: firstSnooze, at: Fixtures.now)
        let second = try #require(next([reminder], ledger: once))

        let secondSnooze = Fixtures.now.addingTimeInterval(20 * 60)
        let twice = once.snoozing(second, until: secondSnooze, at: firstSnooze)
        let third = try #require(next([reminder], ledger: twice))

        #expect(third.entries.first?.trigger == .snooze)
        #expect(third.moment == secondSnooze)
    }

    @Test
    func `dismissals are keyed by occurrence`() {
        let today = Fixtures.event("series", startingIn: 1)
        var tomorrow = today
        tomorrow.start = today.start.addingTimeInterval(24 * 60 * 60)
        tomorrow.end = tomorrow.start.addingTimeInterval(30 * 60)
        tomorrow.members = [MemberIdentity(calendarItemIdentifier: "series", occurrenceDate: tomorrow.start)]
        let takeover = Takeover(entries: [Takeover.Entry(item: today, trigger: .start)], moment: today.start)

        let ledger = TakeoverLedger.empty.dismissing(takeover, at: Fixtures.now)

        #expect(next([today, tomorrow], ledger: ledger)?.entries.first?.item == tomorrow)
    }

    // MARK: Private

    private let settings: TakeoverSettings = .default

    private func next(
        _ items: [AgendaItem],
        ledger: TakeoverLedger = .empty,
        settings: TakeoverSettings? = nil,
    ) -> Takeover? {
        TakeoverPlanner.next(
            agenda: Fixtures.agenda(items),
            ledger: ledger,
            now: Fixtures.now,
            settings: settings ?? self.settings,
        )
    }
}
