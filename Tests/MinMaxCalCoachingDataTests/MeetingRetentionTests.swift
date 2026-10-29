import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test
func `retention uses the recording end and deletes the whole meeting at the exact expiry`() async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date()
    var meeting = Meeting(title: "Long meeting", startedAt: now.addingTimeInterval(-72 * 3_600))
    meeting.endedAt = now.addingTimeInterval(-48 * 3_600 + 1)
    meeting.isComplete = true
    meeting.transcript = [.init(text: "Private words.", start: 0, end: 1, source: .system)]
    let store = JSONMeetingStore(directory: directory, clock: { now })
    try await store.save(meeting)
    #expect(try await store.load().first?.transcript == meeting.transcript)
    let reopened = JSONMeetingStore(directory: directory, clock: { now.addingTimeInterval(1) })
    #expect(try await reopened.load().isEmpty)
    #expect(try await JSONMeetingStore(directory: directory).load().isEmpty)
    #expect(FileManager.default
        .fileExists(atPath: directory.appending(path: "\(meeting.id).json").path(percentEncoded: false)) == false)
}

@Test(arguments: [MeetingRetention.oneWeek, .thirtyDays])
func `changing retention sanitises old history and stale edits cannot restore expired meetings`(
    retention: MeetingRetention
) async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var meeting = Meeting(title: "Old", startedAt: .now.addingTimeInterval(-72 * 3_600))
    meeting.isComplete = true
    meeting.transcript = [.init(text: "Private words.", start: 0, end: 1, source: .system)]
    let store = JSONMeetingStore(directory: directory)
    _ = try await store.load(meetingRetention: retention)
    try await store.save(meeting)
    #expect(try await store.load(meetingRetention: retention).first?.transcript == meeting.transcript)
    #expect(try await store.load(meetingRetention: .twoDays).isEmpty)
    meeting.names["speaker-1"] = "Sam"
    try await store.save(meeting)
    #expect(try await store.load().isEmpty)
    #expect(FileManager.default
        .fileExists(atPath: directory.appending(path: "\(meeting.id).json").path(percentEncoded: false)) == false)
}

@Test
func `active checkpoints keep their words until recording stops or history reopens`() async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONMeetingStore(directory: directory)
    var meeting = Meeting(title: "Checkpoint", startedAt: .now.addingTimeInterval(-72 * 3_600))
    meeting.transcript = [.init(text: "Still recording.", start: 0, end: 1, source: .system)]
    try await store.save(meeting)
    #expect(try await store.load(preserving: meeting.id).first?.transcript == meeting.transcript)
    #expect(try await JSONMeetingStore(directory: directory).load().isEmpty)
}

@Test(arguments: [false, true])
func `meetings without transcripts also expire`(legacy: Bool) async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var meeting = Meeting(title: "Summary only", startedAt: .now.addingTimeInterval(-72 * 3_600))
    meeting.transcript = legacy ? nil : []
    meeting.isComplete = true
    meeting.names["speaker-1"] = "Sam"
    meeting.calendarParticipantNames = ["Sam"]
    meeting.segments = [.init(speakerID: "me", start: 0, end: 5)]
    let store = JSONMeetingStore(directory: directory)
    _ = try await store.load(meetingRetention: .thirtyDays)
    try await store.save(meeting)
    #expect(try await store.load(meetingRetention: .twoDays).isEmpty)
    #expect(FileManager.default
        .fileExists(atPath: directory.appending(path: "\(meeting.id).json").path(percentEncoded: false)) == false)
}
