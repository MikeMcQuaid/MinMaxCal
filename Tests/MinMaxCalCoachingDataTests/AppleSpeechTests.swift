@unsafe @preconcurrency import AVFoundation
import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Speech
import Testing

struct AppleSpeechTests {
    @Test
    func `recognition ignores punctuation and untimed text while keeping source and clock`() {
        var text = AttributedString("untimed")
        var word = AttributedString(" hello ")
        word.audioTimeRange = CMTimeRange(
            start: CMTime(seconds: 12, preferredTimescale: 16_000),
            duration: CMTime(seconds: 0.5, preferredTimescale: 16_000),
        )
        text += word
        var punctuation = AttributedString(".")
        punctuation.audioTimeRange = word.audioTimeRange
        text += punctuation
        #expect(AppleSpeechSession.words(from: text, source: .system) == [
            TranscriptWord(text: "hello .", start: 12, end: 12.5, source: .system)
        ])
        #expect(AppleSpeechSession.words(from: punctuation, source: .microphone).isEmpty)
    }

    @Test
    @available(macOS 27, *)
    func `converted recognition audio anchors once then advances by sample count`() throws {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false,
        ))
        let input = try SpeechInput(format: format)
        #expect(try input.input(samples: [], at: 0) == nil)
        let samples = Array(repeating: Float(0.25), count: 3_200)
        let first = try #require(try input.input(samples: samples, at: 10))
        #expect(first.bufferStartTime?.seconds == 10)
        #expect(first.bufferFormat.commonFormat == .pcmFormatInt16)
        #expect(first.bufferDuration.seconds == 0.2)
        let second = try #require(try input.input(samples: samples, at: 10.199))
        #expect(second.bufferStartTime == nil)
        #expect(second.bufferDuration.seconds == 0.2)
    }

    @Test
    func `capture snapshots microphone voice state without marking system audio`() async throws {
        let frames = AsyncThrowingStream<AudioFrame, any Error>.makeStream()
        let output = AudioOutput(continuation: frames.continuation, epoch: 0)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 320))
        buffer.frameLength = 320
        let data = try unsafe #require(buffer.floatChannelData?[0])
        unsafe data.initialize(repeating: 0, count: 320)
        output.updateVoiceActivity(true, hostTime: AVAudioTime.hostTime(forSeconds: 0.002))
        output.updateVoiceActivity(false, hostTime: AVAudioTime.hostTime(forSeconds: 0.01))
        output.receive(buffer, hostTime: 0, isMicrophone: true)
        output.receive(buffer, hostTime: 0, isMicrophone: false)
        output.receive(buffer, hostTime: AVAudioTime.hostTime(forSeconds: 0.02), isMicrophone: true)
        frames.continuation.finish()
        var received = [AudioFrame]()
        for try await frame in frames.stream {
            received.append(frame)
        }
        #expect(received.map(\.isMicrophoneSpeech) == [true, false, false])
        let interval = try #require(received.first?.microphoneActivity.first)
        #expect(abs(interval.lowerBound - 0.002) < 0.000001)
        #expect(abs(interval.upperBound - 0.01) < 0.000001)
    }
}
