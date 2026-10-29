@unsafe @preconcurrency import AVFoundation
import CoreAudio
import FluidAudio
import Foundation
import MinMaxCalCoachingDomain

// MARK: - SystemAudioRecorder

@preconcurrency
@MainActor
public final class SystemAudioRecorder: MeetingRecorder {
    // MARK: Lifecycle

    public init(modelDirectory: URL = SpeechModels.defaultDirectory) {
        self.modelDirectory = modelDirectory
    }

    // MARK: Public

    // swiftlint:disable:next function_body_length - One audio capture operation.
    public func start(
        reduceSpeakerEcho: Bool
    ) async throws -> AsyncThrowingStream<
        SpeechUpdate,
        any Error,
    > {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw RecordingError.microphoneDenied
        }

        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.bundleIDs = Bundle.main.bundleIdentifier.map { [$0] } ?? []
        description.name = "MinMaxCal meeting audio"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        let processor = try await SpeechModels(directory: modelDirectory)
            .processor(reduceSpeakerEcho: reduceSpeakerEcho)
        try Task.checkCancellation()
        let frames = AsyncThrowingStream<
            AudioFrame,
            any Error,
                // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        >.makeStream(bufferingPolicy: .bufferingOldest(1_024))
        let updates = AsyncThrowingStream<
            SpeechUpdate,
            any Error,
        >.makeStream(bufferingPolicy: .bufferingNewest(1))
        let output = AudioOutput(continuation: frames.continuation)
        captureOutput = output
        worker = Task {
            do {
                var lastUpdate = -Double.infinity
                for try await frame in frames.stream {
                    try await processor.accept(frame)
                    // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
                    if frame.time - lastUpdate >= 0.25 {
                        await updates.continuation.yield(processor.snapshot())
                        lastUpdate = frame.time
                    }
                }
                try await updates.continuation.yield(processor.finish())
                updates.continuation.finish()
            } catch {
                await updates.continuation.yield(processor.snapshot())
                updates.continuation.finish(throwing: error)
            }
        }
        do {
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw RecordingError.noMicrophone
            }

            let receive: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { @Sendable buffer, time in
                guard time.isHostTimeValid else {
                    output.continuation.finish(throwing: RecordingError.interrupted)
                    return
                }

                output.receive(
                    buffer,
                    hostTime: time.hostTime,
                    isMicrophone: true,
                )
            }
            if #available(macOS 27, *) {
                // swiftlint:disable:next no_magic_numbers - Microphone callback buffer size.
                try input.installAudioTap(onBus: 0, bufferSize: 4_096, format: format) { buffer, time in
                    receive(AVAudioPCMBuffer(copying: buffer), time)
                }
            } else {
                Self.installLegacyTap(on: input, format: format, receive: receive)
            }
            microphoneEngine = engine
            let tap = SystemAudioTap()
            systemTap = tap
            try tap.start(
                description: description,
                output: output,
            )
            try engine.start()
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: nil,
            ) { _ in output.continuation.finish(throwing: RecordingError.interrupted) }
            return updates.stream
        } catch {
            stopCapture()
            frames.continuation.finish(throwing: error)
            await worker?.value
            captureOutput = nil
            worker = nil
            throw error
        }
    }

    public func stop() async {
        if let stopping = stopTask {
            await stopping.value
            return
        }
        stopCapture()
        let stopping = Task { [output = captureOutput, worker] in
            output?.continuation.finish()
            await worker?.value
        }
        stopTask = stopping
        await stopping.value
        captureOutput = nil
        worker = nil
        stopTask = nil
    }

    // MARK: Private

    private var microphoneEngine: AVAudioEngine?
    private var systemTap: SystemAudioTap?
    private var configurationObserver: NSObjectProtocol?
    private var captureOutput: AudioOutput?
    private var worker: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?

    private let modelDirectory: URL

    @diagnose(DeprecatedDeclaration, as: ignored, reason: "macOS 26 fallback; the read-only tap requires macOS 27")
    @available(macOS, introduced: 26, obsoleted: 27)
    private static func installLegacyTap(
        on input: AVAudioInputNode,
        format: AVAudioFormat,
        receive: @escaping @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void,
    ) {
        // swiftlint:disable:next no_magic_numbers - Microphone callback buffer size.
        input.installTap(onBus: 0, bufferSize: 4_096, format: format, block: receive)
    }

    private func stopCapture() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        microphoneEngine?.stop()
        microphoneEngine?.inputNode.removeTap(onBus: 0)
        microphoneEngine = nil
        systemTap?.stop()
        systemTap = nil
    }
}

// MARK: - AudioOutput
