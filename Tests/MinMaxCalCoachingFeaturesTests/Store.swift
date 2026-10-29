import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

actor Store: MeetingStore {
    var meetings: [Meeting] = []

    func load(meetingRetention _: MeetingRetention = .twoDays, preserving _: UUID? = nil) -> [Meeting] {
        meetings
    }

    func save(_ meeting: Meeting) {
        meetings.removeAll { $0.id == meeting.id }
        meetings.append(meeting)
    }

    func delete(id: UUID) {
        meetings.removeAll { $0.id == id }
    }
}
