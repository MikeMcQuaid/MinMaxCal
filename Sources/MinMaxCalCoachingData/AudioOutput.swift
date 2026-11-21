import AppKit
@unsafe @preconcurrency import AVFoundation
import CoreAudio
import FluidAudio
import Synchronization

final class AudioOutput: Sendable {
    // MARK: Lifecycle

    init(
        continuation: AsyncThrowingStream<
            AudioFrame,
            any Error,
        >.Continuation,
        // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
        epoch: UInt64 = mach_absolute_time(),
    ) {
        self.continuation = continuation
        self.epoch = epoch
    }

    // MARK: Internal

    let continuation: AsyncThrowingStream<
        AudioFrame,
        any Error,
    >.Continuation

    /// Reading under the lock lets teardown wait for in-flight device queries.
    func updateVoiceActivity(
        _ detected: @autoclosure () throws -> Bool,
        // swiftlint:disable:next discouraged_default_parameter - Use the shared host clock for voice notifications.
        hostTime: UInt64 = mach_absolute_time(),
    ) rethrows {
        guard hostTime >= epoch else {
            return
        }

        try microphoneVoice.withLock { state in
            guard state.enabled else {
                return
            }

            try state.activity.update(detected(), at: AVAudioTime.seconds(forHostTime: hostTime - epoch))
        }
    }

    func stopVoiceActivityUpdates() {
        microphoneVoice.withLock { $0.enabled = false }
    }

    func receive(
        _ buffer: AVAudioPCMBuffer,
        hostTime: UInt64,
        isMicrophone: Bool,
    ) {
        guard buffer.frameLength > 0,
              hostTime >= epoch
        else {
            return
        }

        do {
            let time = AVAudioTime.seconds(forHostTime: hostTime - epoch)
            let frame = try AudioFrame(
                samples: converter.resampleBuffer(buffer),
                time: time,
                isMicrophone: isMicrophone,
                microphoneActivity: isMicrophone ? microphoneVoice.withLock { state in
                    state.activity.intervals(
                        from: time,
                        to: time + Double(buffer.frameLength) / buffer.format.sampleRate,
                    )
                } : [],
            )
            if case .dropped = continuation.yield(frame) {
                continuation.finish(throwing: RecordingError.audioOverrun)
            }
        } catch {
            continuation.finish(throwing: error)
        }
    }

    // MARK: Private

    private let microphoneVoice: Mutex = .init((enabled: true, activity: MicrophoneActivity()))
    private let converter: AudioConverter = .init()
    private let epoch: UInt64
}
