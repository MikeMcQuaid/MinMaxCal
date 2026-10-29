import AVFoundation
import CoreAudio
import Foundation
@testable import MinMaxCalCoachingData
import Synchronization
import Testing

@Test
func `capture requests audio permission without screen access`() throws {
    let plist = try Data(contentsOf: URL(filePath: "App/Info.plist"))
    let propertyList = try unsafe PropertyListSerialization.propertyList(
        from: plist,
        format: nil,
    )
    let properties = try #require(propertyList as? [String: Any])
    #expect(properties["NSAudioCaptureUsageDescription"] is String)
    #expect(properties["NSMicrophoneUsageDescription"] is String)
    #expect(properties["NSScreenCaptureUsageDescription"] == nil)
}

@Test
func `microphone and system audio preserve their shared clock and copy callback samples`() async throws { // swiftlint:disable:this function_body_length line_length - Complete scenario.
    let frames = AsyncThrowingStream<
        AudioFrame,
        any Error,
    >.makeStream()
    let epoch = AVAudioTime.hostTime(forSeconds: 100)
    let output = AudioOutput(
        continuation: frames.continuation,
        epoch: epoch,
    )
    let format = try #require(AVAudioFormat(
        standardFormatWithSampleRate: 16_000,
        channels: 1,
    ))
    let buffer = try #require(AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: 1_600,
    ))
    buffer.frameLength = 1_600
    let samples = unsafe buffer
        // swiftlint:disable:next force_unwrapping - The fixture format is mono Float32.
        .floatChannelData![0] // swiftformat:disable:this noForceUnwrapInTests - Raw pointer fixture.

    unsafe samples.update(
        repeating: 0.25,
        count: 1_600,
    )
    output.receive(
        buffer,
        hostTime: epoch + AVAudioTime.hostTime(forSeconds: 1),
        isMicrophone: false,
    )
    unsafe samples.update(
        repeating: 0.5,
        count: 1_600,
    )
    output.receive(
        buffer,
        hostTime: epoch + AVAudioTime.hostTime(forSeconds: 1.5),
        isMicrophone: true,
    )
    unsafe samples.update(
        repeating: 0,
        count: 1_600,
    )
    frames.continuation.finish()
    var received = [AudioFrame]()
    for try await frame in frames.stream {
        received.append(frame)
    }
    #expect(received.count == 2)
    #expect(received[0].samples.allSatisfy { $0 == 0.25 })
    #expect(received[1].samples.allSatisfy { $0 == 0.5 })
    #expect(received[0].isMicrophone == false)
    #expect(received[1].isMicrophone)
    #expect(abs(received[0].time - 1) < 0.0001)
    #expect(abs(received[1].time - 1.5) < 0.0001)
}

@Test
func `audio callback overflow fails instead of silently losing meeting speech`() async throws {
    let frames = AsyncThrowingStream<
        AudioFrame,
        any Error,
    >.makeStream(bufferingPolicy: .bufferingOldest(1))
    let output = AudioOutput(
        continuation: frames.continuation,
        epoch: 0,
    )
    let format = try #require(AVAudioFormat(
        standardFormatWithSampleRate: 16_000,
        channels: 1,
    ))
    let buffer = try #require(AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: 1_600,
    ))
    buffer.frameLength = 1_600
    unsafe buffer.floatChannelData?[0].update(
        repeating: 0,
        count: 1_600,
    )
    output.receive(
        buffer,
        hostTime: 1,
        isMicrophone: false,
    )
    output.receive(
        buffer,
        hostTime: 2,
        isMicrophone: true,
    )
    var received = 0
    do {
        for try await _ in frames.stream {
            received += 1
        }
        Issue.record("Overflow did not report an error")
    } catch RecordingError.audioOverrun {
        #expect(received == 1)
    } catch {
        Issue.record("Unexpected capture error: \(error)")
    }
}

@Test
func `borrowed core audio buffers are resampled before returning to the driver`() async throws {
    let frames = AsyncThrowingStream<
        AudioFrame,
        any Error,
    >.makeStream()
    let output = AudioOutput(
        continuation: frames.continuation,
        epoch: 0,
    )
    let format = try #require(AVAudioFormat(
        standardFormatWithSampleRate: 48_000,
        channels: 1,
    ))
    let source = try #require(AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: 4_800,
    ))
    source.frameLength = 4_800
    unsafe source.floatChannelData?[0].update(
        repeating: 0.5,
        count: 4_800,
    )
    let borrowedBuffer = unsafe AVAudioPCMBuffer(
        pcmFormat: format,
        bufferListNoCopy: source.audioBufferList,
        deallocator: nil,
    )
    let borrowed = try #require(borrowedBuffer)
    #expect(borrowed.frameLength == 4_800)
    output.receive(
        borrowed,
        hostTime: 1,
        isMicrophone: false,
    )
    unsafe source.floatChannelData?[0].update(
        repeating: 0,
        count: 4_800,
    )
    frames.continuation.finish()
    var received = [AudioFrame]()
    for try await frame in frames.stream {
        received.append(frame)
    }
    let frame = try #require(received.first)
    #expect(frame.samples.count == 1_600)
    #expect(frame.samples[800] > 0.4)
}

@Test
@MainActor
func `system audio callback runs on the driver queue`() async throws { // swiftlint:disable:this function_body_length line_length - Complete scenario.
    let frames = AsyncThrowingStream<
        AudioFrame,
        any Error,
    >.makeStream()
    let output = AudioOutput(
        continuation: frames.continuation,
        epoch: 0,
    )
    let format = try #require(AVAudioFormat(
        standardFormatWithSampleRate: 48_000,
        channels: 1,
    ))
    let callback = unsafe Mutex(SystemAudioTap.makeIOBlock(
        format: format,
        output: output,
    ))
    // swiftlint:disable:next closure_body_length - One complete synthetic scenario.
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
        // swiftlint:disable:next closure_body_length - One complete synthetic scenario.
        DispatchQueue(label: "MinMaxCalTests.audio-driver").async {
            do {
                let driverFormat = try #require(AVAudioFormat(
                    standardFormatWithSampleRate: 48_000,
                    channels: 1,
                ))
                let buffer = try #require(AVAudioPCMBuffer(
                    pcmFormat: driverFormat,
                    frameCapacity: 4_800,
                ))
                buffer.frameLength = 4_800
                unsafe buffer.floatChannelData?[0].update(
                    repeating: 0.5,
                    count: 4_800,
                )
                var time = AudioTimeStamp()
                time.mHostTime = AVAudioTime.hostTime(forSeconds: 2)
                time.mFlags = .hostTimeValid
                withUnsafePointer(to: &time) { timestamp in
                    unsafe callback.withLock { block in
                        unsafe block(
                            timestamp,
                            buffer.audioBufferList,
                            timestamp,
                            buffer.mutableAudioBufferList,
                            timestamp,
                        )
                    }
                }
                unsafe buffer.floatChannelData?[0].update(
                    repeating: 0,
                    count: 4_800,
                )
                output.continuation.finish()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    var received = [AudioFrame]()
    for try await frame in frames.stream {
        received.append(frame)
    }
    let frame = try #require(received.first)
    #expect(received.count == 1)
    #expect(frame.samples.count == 1_600)
    #expect(frame.samples[800] > 0.4)
    #expect(abs(frame.time - 2) < 0.0001)
    #expect(frame.isMicrophone == false)
}
