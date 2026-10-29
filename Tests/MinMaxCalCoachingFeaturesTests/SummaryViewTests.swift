import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import SwiftUI
import Testing

@Test(arguments: [
    false,
    true,
])
func `summary and coaching render`(unverified: Bool) throws { // swiftlint:disable:this function_body_length line_length - Complete scenario.
    var meeting = Meeting(title: "Weekly team check-in")
    meeting.duration = 360
    meeting.names = ["me": "You", "speaker-1": "Alex", "speaker-2": "Sam"]
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 45),
        .init(speakerID: "speaker-1", start: 43, end: 90),
        .init(speakerID: "me", start: 95, end: 165),
        .init(speakerID: "speaker-2", start: 168, end: 230),
        .init(speakerID: "speaker-1", start: 235, end: 280),
        .init(speakerID: "me", start: 285, end: 360),
    ]
    if unverified {
        meeting.segments.append(.init(speakerID: "unverified-microphone", start: 240, end: 300))
    }
    meeting.transcript = [
        .init(text: "Could you walk us through the options?", start: 10, end: 15, source: .microphone),
        .init(text: "Yes. There are two approaches worth considering.", start: 50, end: 55, source: .system),
        .init(text: "Let’s hear Sam’s view before we decide.", start: 110, end: 115, source: .microphone),
    ]
    let view = NSHostingView(rootView: VStack(
        alignment: .leading,
        spacing: 24,
    ) {
        Text(meeting.title).font(.largeTitle.bold())
        TranscriptView(meeting: meeting)
        CoachingView(
            meeting: meeting,
            targetShare: 0.4,
            turnLimit: 60,
        )
        SummaryView(
            meeting: meeting,
            rename: { _, _ in
            },
        )
    }
    .padding(16)
    .frame(width: 420)
    .buttonStyle(.glass)
    .background(.background)
    .environment(\.colorScheme, .light))
    view.frame = CGRect(origin: .zero, size: view.fittingSize)
    view.layoutSubtreeIfNeeded()
    let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let image = try #require(bitmap.cgImage)
    #expect(view.bounds.width == 420)
    #expect(view.bounds.height > 400)
    if let directory = ProcessInfo.processInfo.environment["MINMAXCAL_COACHING_SNAPSHOT_DIRECTORY"] {
        let url = URL(filePath: directory)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
        )
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(
            using: .png,
            properties: [:],
        ))
        try png.write(to: url.appending(path: unverified ? "summary-unverified.png" : "summary.png"))
    }
}
