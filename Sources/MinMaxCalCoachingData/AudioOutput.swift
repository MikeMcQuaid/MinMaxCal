import AppKit
@unsafe @preconcurrency import AVFoundation
import CoreAudio
import FluidAudio

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
            let frame = try AudioFrame(
                samples: converter.resampleBuffer(buffer),
                time: AVAudioTime.seconds(forHostTime: hostTime - epoch),
                isMicrophone: isMicrophone,
            )
            if case .dropped = continuation.yield(frame) {
                continuation.finish(throwing: RecordingError.audioOverrun)
            }
        } catch {
            continuation.finish(throwing: error)
        }
    }

    // MARK: Private

    private let converter: AudioConverter = .init()
    private let epoch: UInt64
}
