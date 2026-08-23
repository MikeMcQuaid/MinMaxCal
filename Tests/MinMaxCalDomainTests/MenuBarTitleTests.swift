import Foundation
import MinMaxCalDomain
import Testing

struct MenuBarTitleTests {
    @Test
    func `keeps the beginning and end of long titles`() {
        #expect(MenuBarTitle.truncate("Quarterly review with finance", limit: 24) == "Quarterly rev…th finance")
        #expect(MenuBarTitle.truncate("Weekly planning", limit: 24) == "Weekly planning")
    }

    @Test
    func `truncates by grapheme cluster`() {
        let flags = String(repeating: "🇬🇧", count: 30)
        let truncated = MenuBarTitle.truncate(flags, limit: 10)
        #expect(truncated.count == 10)
        #expect(truncated.contains("…"))
    }

    @Test
    func `renders the next timed item with its countdown`() {
        let agenda = Fixtures.agenda([
            Fixtures.event("all-day", title: "Offsite", startingIn: -60, duration: 600, isAllDay: true),
            Fixtures.event("next", title: "Weekly planning", startingIn: 112),
            Fixtures.event("later", title: "Later", startingIn: 200),
        ])
        #expect(MenuBarTitle.render(agenda: agenda, now: Fixtures.now) == "Weekly planning 1h52m")
    }

    @Test
    func `switches to the time until the end once started`() {
        let agenda = Fixtures.agenda([Fixtures.event("now", title: "Weekly planning", startingIn: -2, duration: 30)])
        #expect(MenuBarTitle.render(agenda: agenda, now: Fixtures.now) == "Weekly planning 28m")
    }

    @Test
    func `is nil when nothing is upcoming`() {
        let agenda = Fixtures.agenda([Fixtures.reminder("undated", isAllDay: true)])
        #expect(MenuBarTitle.render(agenda: agenda, now: Fixtures.now) == nil)
        #expect(MenuBarTitle.render(agenda: .empty, now: Fixtures.now) == nil)
    }
}
