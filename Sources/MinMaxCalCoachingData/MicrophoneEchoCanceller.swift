import FluidAudio
import Foundation

// MARK: - EchoAudioBuffer

// MARK: - MicrophoneEchoCanceller

actor MicrophoneEchoCanceller {
    // MARK: Lifecycle

    // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
    init(modelDirectory: URL = SpeechModels
        .defaultDirectory) async throws
    // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
    { // Voice detection already works in 256 ms blocks; batching reduces CPU use.
        stream = try await LocalVqeManager(modelDirectory: modelDirectory.appending(path: Repo.localVqe.folderName))
            .makeStream()
    }

    // MARK: Internal

    func accept(_ frame: AudioFrame) async throws -> [AudioFrame] {
        try buffer.append(frame)
        return try await drain(finalising: false)
    }

    func finish() async throws -> [AudioFrame] {
        var frames = try await drain(finalising: true)
        if let tail = try await output(stream.flush()) {
            frames.append(tail)
        }
        return frames
    }

    // MARK: Private

    private let stream: LocalVqeStream
    private var buffer: EchoAudioBuffer = .init()
    private var origin: Double?
    private var outputSamples = 0
    private var inputSamples = 0
    private var unverified: [Range<Int>] = []

    private func drain(finalising: Bool) async throws -> [AudioFrame] {
        var frames = [AudioFrame]()
        while let pair = buffer.next(finalising: finalising) {
            origin = origin ?? pair.time
            if pair.hasCompleteReference == false {
                unverified.append(inputSamples ..< (inputSamples + pair.microphone.count))
            }
            inputSamples += pair.microphone.count
            if let frame = try await output(stream.enhance(
                mic: pair.microphone,
                reference: pair.reference,
            )) {
                frames.append(frame)
            }
        }
        return frames
    }

    private func output(_ samples: [Float]) -> AudioFrame? {
        guard let origin, samples.isEmpty == false else {
            return nil
        }

        let end = outputSamples + samples.count
        defer {
            outputSamples = end
            unverified.removeAll { $0.upperBound <= end }
        }
        return AudioFrame(
            samples: samples,
            // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
            time: origin + Double(outputSamples) / 16_000,
            isMicrophone: true,
            isUnverifiedMicrophone: unverified.contains { $0.overlaps(outputSamples ..< end) },
        )
    }
}
