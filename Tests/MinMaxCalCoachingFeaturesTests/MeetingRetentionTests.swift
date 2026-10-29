import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

@Test
func `meeting retention defaults to two days and persists an explicit seven day choice`() async throws {
    let suite = "MeetingRetentionTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models(), defaults: defaults)
    #expect(model.meetingRetention == .twoDays)
    model.meetingRetention = .oneWeek
    await model.deactivate()
    let reopened = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models(), defaults: defaults)
    #expect(reopened.meetingRetention == .oneWeek)
    await reopened.deactivate()
}

@Test
func `expiry clears the selected meeting but keeps a fresh unsaved recording available`() async {
    let model = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models())
    let expired = Meeting(title: "Expired", startedAt: .now.addingTimeInterval(-72 * 3_600))
    model.current = expired
    model.selectedID = expired.id
    await model.refreshHistory()
    #expect(model.current == nil)
    #expect(model.selectedID == nil)
    #expect(model.selected == nil)

    let fresh = Meeting(title: "Unsaved recording")
    model.current = fresh
    model.selectedID = fresh.id
    await model.refreshHistory()
    #expect(model.selected == fresh)
    await model.deactivate()
}

@Test(arguments: [(0, 48), (24, 48), (720, 720)])
func `saved retention choices use supported limits or fall back to 48 hours`(
    savedHours: Int,
    expectedHours: Int,
) async throws {
    let suite = "MeetingRetentionTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(savedHours, forKey: "coaching.transcriptRetentionHours")
    let model = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models(), defaults: defaults)
    #expect(model.meetingRetention.rawValue == expectedHours)
    await model.deactivate()
}
