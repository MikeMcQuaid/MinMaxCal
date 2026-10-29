@testable import MinMaxCalCoachingDomain
import Testing

@Test
func `reminders require a new threshold crossing and two minutes between alerts`() {
    var reminder = CoachingReminder()
    for (time, needsRoom, expected) in [
        (29.0, false, false), (30, true, true), (31, true, false),
        (40, false, false), (41, true, false), (151, true, false),
        (152, false, false), (153, true, true),
    ] {
        let result = reminder.shouldNotify(
            needsRoom: needsRoom,
            at: time,
        )
        #expect(result == expected)
    }
}
