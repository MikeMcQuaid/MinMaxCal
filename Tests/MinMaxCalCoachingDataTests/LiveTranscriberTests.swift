import FluidAudio
import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test(.enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_TRANSCRIPTION"] == "1"))
func `recorded speech produces a live transcript and flushes final words`() async throws {
    let speech = try AudioConverter().resampleAudioFile(URL(
        filePath:
        // swiftlint:disable:next line_length - Keep this fixture path or displayed sentence intact.
        ".build/checkouts/FluidAudio/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/Fixtures/01-validation-request-21.4s.wav"
    ))
    let processor = try await SpeechProcessor(
        reduceSpeakerEcho: false,
        transcribe: true,
    )
    for start in stride(
        from: 0,
        to: speech.count,
        by: 4_096,
    ) {
        for microphone in [false, true] {
            try await processor.accept(.init(
                samples: Array(speech[start ..< min(start + 4_096, speech.count)
                ]),
                time: (microphone ? 10 : 5) + Double(start) / 16_000,
                isMicrophone: microphone,
            ))
        }
    }
    let live = await processor.snapshot()
    #expect(live.transcript.count(where: { $0.source == .microphone }) > 10)
    #expect(live.transcript.count(where: { $0.source == .system }) > 10)
    let final = try await processor.finish()
    #expect(final.transcript.count >= live.transcript.count)
    #expect(final.transcript.allSatisfy { $0.start >= ($0.source == .microphone ? 10 : 5) })
    var meeting = Meeting(title: "Speech fixture")
    meeting.transcript = final.transcript
    meeting.segments = final.segments
    for segment in final.segments {
        meeting.names[segment.speakerID] = segment.speakerID == "me" ? "Mike" : "Alex"
    }
    #expect(meeting.transcriptText.contains("Alex:"))
    #expect(meeting.transcriptText.contains("Mike:"))
    #expect(meeting.transcriptText.lowercased().contains("validate"))
    if let directory = ProcessInfo.processInfo.environment["MINMAXCAL_COACHING_SNAPSHOT_DIRECTORY"] {
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
        )
        try meeting.transcriptText.write(
            toFile: directory + "/fixture-transcript.txt",
            atomically: true,
            encoding: .utf8,
        )
    }
}
