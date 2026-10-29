import Foundation

@preconcurrency
@MainActor
public protocol MeetingNotifier: AnyObject {
    func requestAuthorization() async throws -> Bool
    func notify(_ message: String) async throws
    func clear()
    func updateMeetingPrompts(
        _ meetings: [CalendarMeeting],
        at date: Date,
    ) async throws
}
