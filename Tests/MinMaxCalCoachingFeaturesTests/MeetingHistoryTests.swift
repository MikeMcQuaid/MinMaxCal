import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import SwiftUI
import Testing

@Test
func `history excludes a live checkpoint and keeps stopped unsaved recordings available`() {
    let model = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models())
    let previous = Meeting(title: "Previous")
    let current = Meeting(title: "Current")
    model.meetings = [current, previous]
    model.current = current
    model.phase = .recording
    #expect(model.history == [previous])
    model.selectedID = previous.id
    #expect(model.current == current)
    #expect(model.history == [previous])
    model.phase = .stopping
    #expect(model.history == [previous])
    model.phase = .idle
    #expect(model.history == [current, previous])
    var edited = current
    edited.names["me"] = "Mike"
    model.current = edited
    #expect(model.history == [edited, previous])
    model.meetings = [previous]
    #expect(model.history == [edited, previous])
    model.current = nil
    #expect(model.history == [previous])
}

@Test
func `finishing a recording selects its saved details after browsing older history`() async throws {
    let recorder = Recorder()
    let store = Store()
    let previous = Meeting(title: "Previous")
    await store.save(previous)
    let model = MeetingModel(recorder: recorder, store: store, speechModels: Models())
    await model.load()
    model.start()
    try await waitFor { model.phase == .recording }
    let current = try #require(model.current)
    model.selectedID = previous.id
    await model.stop()
    #expect(model.selectedID == current.id)
    #expect(model.selected?.id == current.id)
    #expect(model.history.count == 2)
    await model.deactivate()
}

@Test(arguments: [(false, false), (true, false), (false, true)])
func `history rows render inline details and actions at menu bar width`(expanded: Bool, deleting: Bool) throws {
    var meeting = Meeting(title: "Weekly planning")
    meeting.duration = 30
    meeting.isComplete = true
    meeting.names["speaker-1"] = "Sam"
    meeting.segments = [.init(speakerID: "speaker-1", start: 0, end: 10)]
    meeting.transcript = [.init(text: "Hello.", start: 0, end: 1, source: .system)]
    let model = MeetingModel(recorder: Recorder(), store: Store(), speechModels: Models())
    model.meetings = [meeting]
    model.selectedID = expanded ? meeting.id : nil
    let view = NSHostingView(rootView: MeetingHistoryRow(
        model: model,
        meeting: meeting,
        targetShare: 0.4,
        turnLimit: 60,
        deleting: .constant(deleting ? meeting.id : nil),
    )
    .padding(16)
    .frame(width: 420)
    .buttonStyle(.glass)
    .background(.background)
    .environment(\.colorScheme, .light))
    view.frame = CGRect(origin: .zero, size: view.fittingSize)
    view.layoutSubtreeIfNeeded()
    let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    #expect(view.bounds.width == 420)
    #expect(expanded ? view.bounds.height > 200 : view.bounds.height < 200)
    if let directory = ProcessInfo.processInfo.environment["MINMAXCAL_COACHING_SNAPSHOT_DIRECTORY"] {
        let url = URL(filePath: directory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url.appending(path: "history-\(expanded)-\(deleting).png"))
    }
}
