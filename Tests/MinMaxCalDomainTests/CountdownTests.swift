import Foundation
import MinMaxCalDomain
import Testing

struct CountdownTests {
    // MARK: Internal

    @Test(arguments: expectations)
    func `uses the two largest units`(minutes: Double, expected: String) {
        let target = Fixtures.now.addingTimeInterval(minutes * 60)
        #expect(Countdown.format(from: Fixtures.now, to: target) == expected)
    }

    @Test
    func `counts to the start then to the end`() {
        let event = Fixtures.event("a", startingIn: 10, duration: 30)
        #expect(Countdown.text(for: event, now: Fixtures.now) == "10m")
        #expect(Countdown.text(for: event, now: Fixtures.now.addingTimeInterval(12 * 60)) == "28m")
    }

    @Test
    func `a due reminder reads now`() {
        let reminder = Fixtures.reminder("r", dueIn: -3)
        #expect(Countdown.text(for: reminder, now: Fixtures.now) == "now")
    }

    // MARK: Private

    private static let expectations: [(minutes: Double, expected: String)] = [
        (0, "now"),
        (-5, "now"),
        (0.5, "<1m"),
        (0.99, "<1m"),
        (1, "1m"),
        (45, "45m"),
        (60, "1h"),
        (112, "1h52m"),
        (1_440, "1d"),
        (3_119, "2d3h"),
    ]
}
