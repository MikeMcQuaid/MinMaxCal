import Foundation

public protocol MeetingCalendar: Sendable {
    func meetings(
        around date: Date,
        requestAccess: Bool,
    ) async throws -> [CalendarMeeting]
}
