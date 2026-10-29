import FluidAudio
import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Testing

@Test(.enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_MODELS"] == "1"), arguments: [0, 24])
func `missing playback must not identify another persons voice as me`(referenceBlocks: Int) async throws {
    let playback = try Array(AudioConverter()
        .resampleAudioFile(URL(
            filePath:
            // swiftlint:disable:next line_length - Keep this fixture path or displayed sentence intact.
            ".build/checkouts/FluidAudio/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/Fixtures/01-validation-request-21.4s.wav"
        ))
        .prefix(16_000 * 12))
    let processor = try await SpeechProcessor()
    for start in stride(
        from: 0,
        to: playback.count,
        by: 4_096,
    ) {
        if start < referenceBlocks * 4_096 {
            try await processor.accept(.init(
                samples: Array(playback[start ..< min(start + 4_096, playback.count)
                ]),
                time: Double(start) / 16_000,
                isMicrophone: false,
            ))
        }
        try await processor.accept(.init(
            samples: Array(playback[start ..< min(start + 4_096, playback.count)
            ]),
            time: Double(start) / 16_000,
            isMicrophone: true,
        ))
    }
    let summary = try await processor.finish()
    #expect(summary.segments.contains { $0.speakerID == "me" } == false)
    #expect(summary.segments.contains { $0.speakerID == "unverified-microphone" })
    var meeting = Meeting(title: "Missing playback")
    meeting.duration = summary.duration
    meeting.segments = summary.segments
    #expect(ConversationBalance(
        meeting: meeting,
        targetShare: 0.1,
        turnLimit: 1,
    ).needsRoom == false)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_MODELS"] == "1"))
func `echo output preserves missing reference attribution across model delay and flush`() async throws {
    let canceller = try await MicrophoneEchoCanceller()
    var output = [AudioFrame]()
    for index in 0 ..< 4 {
        if index < 2 {
            output += try await canceller.accept(.init(
                samples: Array(
                    repeating: 0,
                    count: 4_096,
                ),
                time: Double(index) * 0.256,
                isMicrophone: false,
            ))
        }
        output += try await canceller.accept(.init(
            samples: Array(
                repeating: 0,
                count: 4_096,
            ),
            time: Double(index) * 0.256,
            isMicrophone: true,
        ))
    }
    output += try await canceller.finish()
    #expect(output.reduce(0) { $0 + $1.samples.count } == 4 * 4_096)
    #expect(output.contains { $0.isUnverifiedMicrophone == false })
    #expect(output.last?.isUnverifiedMicrophone == true)
    #expect(output
        .contains { $0.isUnverifiedMicrophone == false && $0.time + Double($0.samples.count) / 16_000 > 0.512 } ==
        false)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_MODELS"] == "1"))
func `ongoing microphone speech changes attribution when reference is lost and recovers`() async throws {
    let voice = try Array(AudioConverter()
        .resampleAudioFile(URL(
            filePath:
            // swiftlint:disable:next line_length - Keep this fixture path or displayed sentence intact.
            ".build/checkouts/FluidAudio/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/Fixtures/01-validation-request-21.4s.wav"
        ))
        .prefix(16_000 * 12))
    let processor = try await SpeechProcessor(reduceSpeakerEcho: false)
    for start in stride(
        from: 0,
        to: voice.count,
        by: 4_096,
    ) {
        try await processor.accept(.init(
            samples: Array(voice[start ..< min(start + 4_096, voice.count)
            ]),
            time: Double(start) / 16_000,
            isMicrophone: true,
            isUnverifiedMicrophone: (16 ..< 32).contains(start / 4_096),
        ))
        if (16 ..< 32).contains(start / 4_096) {
            #expect(await (processor.snapshot()).activeSpeakerIDs.contains("me") == false)
        }
    }
    let summary = try await processor.finish()
    let missing = (Double(16 * 4_096) / 16_000) ..< (Double(32 * 4_096) / 16_000)
    #expect(summary.segments.contains { $0.speakerID == "unverified-microphone" })
    #expect(summary.segments.contains { $0.speakerID == "me" && $0.start >= missing.upperBound })
    #expect(summary.segments
        .filter { $0.speakerID == "me" && $0.end > $0.start }
        .allSatisfy { ($0.start ..< $0.end).overlaps(missing) == false })
}

@Test(
    .enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_MODELS"] == "1"),
    arguments: [false, true],
    [1_536, 5_120],
)
func `speaker echo is reduced while my overlapping speech remains`( // swiftlint:disable:this function_body_length line_length - Complete scenario.
    includeNearSpeech: Bool,
    delay: Int,
) async throws {
    let reference = try Array(AudioConverter()
        .resampleAudioFile(URL(
            filePath:
            // swiftlint:disable:next line_length - Keep this fixture path or displayed sentence intact.
            ".build/checkouts/FluidAudio/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/Fixtures/01-validation-request-21.4s.wav"
        ))
        .prefix(16_000 * 12))
    let near = try AudioConverter().resampleAudioFile(URL(
        filePath:
        // swiftlint:disable:next line_length - Keep this fixture path or displayed sentence intact.
        ".build/checkouts/FluidAudio/Tests/FluidAudioTests/ASR/Parakeet/SlidingWindow/Fixtures/02-release-readiness-19.8s.wav"
    ))
    let microphone = reference.indices.map { index in
        (index >= delay ? reference[index - delay] * 0.5 : 0)
            + (index >= delay + 464 ? reference[index - delay - 464] * 0.15 : 0)
            + (includeNearSpeech ? near[index] : 0)
    }
    let transcribe = ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_TRANSCRIPTION"] == "1"
    let processor = try await SpeechProcessor(transcribe: transcribe)
    for start in stride(
        from: 0,
        to: reference.count,
        by: 4_096,
    ) {
        let end = min(start + 4_096, reference.count)
        // Deliver the microphone first, as capture callbacks may arrive in either order.
        try await processor.accept(.init(
            samples: Array(microphone[start ..< end]),
            time: Double(start) / 16_000,
            isMicrophone: true,
        ))
        try await processor.accept(.init(
            samples: Array(reference[start ..< end]),
            time: Double(start) / 16_000,
            isMicrophone: false,
        ))
    }
    let summary = try await processor.finish()
    let speaking = summary.segments.filter { $0.speakerID == "me" }.reduce(0) { $0 + $1.end - $1.start }
    if includeNearSpeech {
        #expect(speaking > 4, "Echo reduction removed too much overlapping speech: only \(speaking) seconds survived")
    } else {
        #expect(speaking < 1, "Speaker playback was counted as \(speaking) seconds of my speech")
    }
    #expect(summary.segments.contains { $0.speakerID != "me" })
    #expect(abs(summary.duration - 12) < 0.001)
    if transcribe {
        var meeting = Meeting(title: "Echo and overlapping speech")
        meeting.segments = summary.segments
        meeting.transcript = summary.transcript
        let microphoneTurns = meeting.transcriptTurns
            .filter { $0.speakerID == "me" || $0.speakerID == "unverified-microphone" }
        #expect(microphoneTurns.isEmpty == !includeNearSpeech)
        #expect(summary.transcript.contains { $0.source == .system })
    }
}
