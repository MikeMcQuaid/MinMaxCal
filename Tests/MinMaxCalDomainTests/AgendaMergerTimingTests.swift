import Foundation
import MinMaxCalDomain
import Testing

struct AgendaMergerTimingTests {
    @Test(arguments: [false, true])
    func `merges identical titles when one boundary differs by half the shorter duration`(sameEnd: Bool) {
        let original = Fixtures.event("original", title: "OpenUK 7th Annual Awards, 2026", duration: 240)
        let copy = Fixtures.event(
            "copy",
            title: " openuk 7th annual awards, 2026 ",
            startingIn: sameEnd ? -90 : 30,
            duration: 360,
            calendar: Fixtures.team,
        )

        for items in [[original, copy], [copy, original]] {
            let merged = AgendaMerger.merge(items, rules: .default)

            #expect(merged.count == 1)
            #expect(merged[0].members == items.flatMap(\.members))
            #expect(merged[0].calendars == items.flatMap(\.calendars))
            #expect(merged[0].start == min(original.start, copy.start))
            #expect(merged[0].end == copy.end)
        }
    }

    @Test
    func `merges the screenshot copies with a thirty minute end difference`() {
        let original = Fixtures.event("original", title: "OpenUK 7th Annual Awards, 2026", duration: 270)
        let copy = Fixtures.event("copy", title: original.title, duration: 240, calendar: Fixtures.team)

        #expect(AgendaMerger.merge([original, copy], rules: .default).count == 1)
    }

    @Test(arguments: [false, true])
    func `prefers the most common times regardless of input order`(preferLonger: Bool) {
        let minority = Fixtures.event("minority", duration: preferLonger ? 240 : 270)
        let majority = Fixtures.event("majority", duration: preferLonger ? 270 : 240, calendar: Fixtures.team)
        let copy = Fixtures.event("copy", duration: preferLonger ? 270 : 240, calendar: Fixtures.home)

        for items in [[minority, majority, copy], [majority, copy, minority], [copy, minority, majority]] {
            let merged = AgendaMerger.merge(items, rules: .default)

            #expect(merged.count == 1)
            #expect(merged[0].start == majority.start)
            #expect(merged[0].end == majority.end)
        }
    }

    @Test(arguments: [([240.0, 240, 270, 300], 240.0), ([240.0, 240, 270, 270], 270.0), ([240.0, 270, 300], 300.0)])
    func `uses the unique plurality or the superset when counts tie`(durations: [Double], expectedDuration: Double) {
        let items = durations.enumerated().map { Fixtures.event(String($0.offset), duration: $0.element) }

        let merged = AgendaMerger.merge(items, rules: .default)

        #expect(merged.count == 1)
        #expect(merged[0].end == Fixtures.event("expected", duration: expectedDuration).end)
    }

    @Test
    func `expands both boundaries when no version is more common`() {
        let original = Fixtures.event("original", invite: "uid", duration: 240)
        let earlier = Fixtures.event("earlier", invite: "uid", startingIn: 0, duration: 270)
        let later = Fixtures.event("later", invite: "uid", duration: 270)

        let merged = AgendaMerger.merge([original, earlier, later], rules: .default)

        #expect(merged[0].start == earlier.start)
        #expect(merged[0].end == later.end)
    }

    @Test
    func `generic members cannot vote for the invitation times`() {
        let busy = Fixtures.event("busy", title: "Busy", invite: "uid", duration: 270)
        let blank = Fixtures.event("blank", title: "", invite: "uid", duration: 270)
        let original = Fixtures.event("original", invite: "uid", duration: 240)

        let merged = AgendaMerger.merge([busy, blank, original], rules: .default)

        #expect(merged[0].start == original.start)
        #expect(merged[0].end == original.end)
    }

    @Test(arguments: [false, true])
    func `keeps events beyond half the shorter duration apart`(sameEnd: Bool) {
        let original = Fixtures.event("original", duration: 60)
        let copy = Fixtures.event("copy", startingIn: sameEnd ? -1 : 30, duration: 91)

        #expect(AgendaMerger.merge([original, copy], rules: .default) == [original, copy])
    }

    @Test
    func `keeps events with both boundaries changed apart`() {
        let original = Fixtures.event("original", duration: 240)
        let copy = Fixtures.event("copy", startingIn: 35, duration: 240)

        #expect(AgendaMerger.merge([original, copy], rules: .default) == [original, copy])
    }

    @Test(arguments: ["Different meeting", "Busy", ""])
    func `requires matching specific titles for inexact timing`(title: String) {
        let original = Fixtures.event("original", duration: 240)
        let copy = Fixtures.event("copy", title: title, duration: 270)

        #expect(AgendaMerger.merge([original, copy], rules: .default) == [original, copy])
    }

    @Test
    func `applies the same tolerance to all day events`() {
        let original = Fixtures.event("original", duration: 2_880, isAllDay: true)
        let copy = Fixtures.event("copy", duration: 4_320, isAllDay: true)

        #expect(AgendaMerger.merge([original, copy], rules: .default).count == 1)
    }

    @Test
    func `does not chain similar timings beyond the first member`() {
        let original = Fixtures.event("original", duration: 60)
        let copy = Fixtures.event("copy", duration: 90)
        let longer = Fixtures.event("longer", duration: 120)

        let merged = AgendaMerger.merge([original, copy, longer], rules: .default)

        #expect(merged.count == 2)
        #expect(merged[0].members == original.members + copy.members)
        #expect(merged[1] == longer)
    }

    @Test
    func `generic copies still merge at the exact times of a similar member`() {
        let original = Fixtures.event("original", duration: 240)
        let copy = Fixtures.event("copy", duration: 270)
        let busy = Fixtures.event("busy", title: "Busy", duration: 270)

        let merged = AgendaMerger.merge([original, copy, busy], rules: .default)

        #expect(merged.count == 1)
        #expect(merged[0].members == original.members + copy.members + busy.members)
    }
}
