import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test
func `meeting retention defaults to 48 hours and deletes the whole file`() async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONMeetingStore(directory: directory)
    var meeting = Meeting(title: "Old meeting", startedAt: .now.addingTimeInterval(-72 * 3_600))
    meeting.duration = 600
    meeting.isComplete = true
    meeting.names["speaker-1"] = "Sam"
    meeting.segments = [.init(speakerID: "me", start: 0, end: 5)]
    meeting.transcript = [.init(text: "Expired private words.", start: 0, end: 1, source: .microphone)]
    try await store.save(meeting)
    #expect(try await store.load().isEmpty)
    #expect(FileManager.default
        .fileExists(atPath: directory.appending(path: "\(meeting.id).json").path(percentEncoded: false)) == false)
}

@Test
func `summaries round trip and can be deleted`() async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = JSONMeetingStore(directory: directory)
    #expect(try await store.load().isEmpty)
    var meeting = Meeting(title: "Weekly planning")
    meeting.segments = [.init(speakerID: "me", start: 1, end: 5)]
    meeting.names["speaker-1"] = "Sam"
    meeting.transcript = [.init(text: "Hello.", start: 1, end: 2, source: .microphone)]
    try await store.save(meeting)
    #expect(try await store.load() == [meeting])
    meeting.isComplete = true
    try await store.save(meeting)
    #expect(try await store.load() == [meeting])
    try await store.delete(id: meeting.id)
    #expect(try await store.load().isEmpty)
}

@Test
func `corrupt history is reported`() async throws {
    let directory = TestScratch.directory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
    )
    try Data("broken".utf8).write(to: directory.appending(path: "broken.json"))
    await #expect(throws: (any Error).self) { try await JSONMeetingStore(directory: directory).load() }
}
