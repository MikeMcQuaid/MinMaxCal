import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

actor CalendarSource: MeetingCalendar {
    // MARK: Lifecycle

    init(events: [CalendarMeeting]) {
        self.events = events
    }

    // MARK: Internal

    var events: [CalendarMeeting]
    var fail = false
    var accessRequests = 0

    func setEvents(_ events: [CalendarMeeting]) {
        self.events = events
    }

    func setFailure(_ fail: Bool) {
        self.fail = fail
    }

    func meetings(
        around _: Date,
        requestAccess: Bool,
    ) throws -> [CalendarMeeting] {
        if requestAccess {
            accessRequests += 1
        }
        if fail {
            throw TestError.failed
        }
        return events
    }
}
