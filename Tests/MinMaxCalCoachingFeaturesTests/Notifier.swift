import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

final class Notifier: MeetingNotifier {
    var authorised = true
    var failDelivery = false
    var requests = 0
    var messages: [String] = []
    var clears = 0
    var scheduled: [CalendarMeeting] = []

    func updateMeetingPrompts(
        _ meetings: [CalendarMeeting],
        at _: Date,
    ) {
        scheduled = meetings
    }

    func requestAuthorization() -> Bool {
        requests += 1
        return authorised
    }

    func notify(_ message: String) throws {
        if failDelivery {
            throw TestError.failed
        }
        messages.append(message)
    }

    func clear() {
        clears += 1
    }
}
