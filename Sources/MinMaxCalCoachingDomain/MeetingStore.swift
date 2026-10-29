import Foundation

public protocol MeetingStore: Sendable {
    func load(meetingRetention: MeetingRetention, preserving activeID: UUID?) async throws -> [Meeting]
    func save(_ meeting: Meeting) async throws
    func delete(id: UUID) async throws
}
