import CoreML
@unsafe @preconcurrency import FluidAudio
import Foundation
import MinMaxCalCoachingDomain

// MARK: - AudioFrame

// MARK: - RecordingError

// MARK: - SpeechProcessor

actor SpeechProcessor {
    // MARK: Lifecycle

    init(
        // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
        reduceSpeakerEcho: Bool = true,
        // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
        transcribe: Bool = false,
        // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
        modelDirectory: URL = SpeechModels.defaultDirectory,
    ) async throws {
        transcriber = transcribe ? try await LiveTranscriber(modelDirectory: modelDirectory) : nil
        try Task.checkCancellation()
        echoCanceller = reduceSpeakerEcho ? try await MicrophoneEchoCanceller(modelDirectory: modelDirectory) : nil
        let configuration = MLModelConfiguration()
        configuration.computeUnits = VadConfig.default.computeUnits
        vad = try VadManager(vadModel: MLModel(
            contentsOf: modelDirectory.appending(path: Repo.vad.folderName)
                .appending(path: ModelNames.VAD.sileroVadFile),
            configuration: configuration,
        ))
        try Task.checkCancellation()
        diarizer = try RollingDiarizer(session: LSEENDSession(modelDirectory: modelDirectory))
    }

    // MARK: Internal

    func accept(_ frame: AudioFrame) async throws {
        guard frame.time.isFinite, frame.time >= 0 else {
            return
        }

        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        let end = frame.time + Double(frame.samples.count) / 16_000
        duration = max(duration, end)
        if let echoCanceller {
            if frame.isMicrophone == false {
                try await analyse(frame)
            }
            for cleaned in try await echoCanceller.accept(frame) {
                try await analyse(cleaned)
            }
        } else {
            try await analyse(frame)
        }
    }

    func finish() async throws -> SpeechUpdate {
        if let echoCanceller {
            for cleaned in try await echoCanceller.finish() {
                try await analyse(cleaned)
            }
        }
        if microphoneSamples.isEmpty == false {
            let count = microphoneSamples.count
            let padded = microphoneSamples + Array(
                repeating: Float.zero,
                count: VadManager.chunkSize - count,
            )
            microphoneSamples.removeAll()
            try await processMicrophone(
                padded,
                actualCount: count,
            )
        }
        try diarizer.finish()
        if let transcriber {
            transcript = try await transcriber.finish()
        }
        return snapshot()
    }

    func snapshot() -> SpeechUpdate {
        var segments = microphoneSegments
        var activeSpeakerIDs = [String]()
        if let speechStart {
            // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
            let end = (microphoneOrigin ?? 0) + Double(microphoneOffset) / 16_000
            if duration - end < 1 {
                activeSpeakerIDs.append(microphoneSpeakerID)
            }
            segments.append(.init(
                speakerID: microphoneSpeakerID,
                start: speechStart,
                end: end,
            ))
        }
        let remote = diarizer.snapshot()
        segments.append(contentsOf: remote.segments)
        // swiftlint:disable:next no_magic_numbers - Recent remote activity threshold.
        if duration - remote.duration < 2 {
            activeSpeakerIDs.append(contentsOf: remote.activeSpeakerIDs)
        }
        return SpeechUpdate(
            segments: segments,
            duration: duration,
            microphoneLevel: microphoneLevel,
            meetingLevel: meetingLevel,
            activeSpeakerIDs: activeSpeakerIDs.sorted(),
            hasMeetingAudio: remoteOrigin != nil,
            transcript: transcript,
        )
    }

    // MARK: Private

    private let diarizer: RollingDiarizer
    private let vad: VadManager
    private let echoCanceller: MicrophoneEchoCanceller?
    private let transcriber: LiveTranscriber?
    private var transcript: [TranscriptWord] = []
    private var vadState: VadStreamState = .initial()
    private var microphoneSamples: [Float] = []
    private var microphoneOffset = 0
    private var remoteSamples = 0
    private var microphoneOrigin: Double?
    private var remoteOrigin: Double?
    private var microphoneSegments: [SpeechSegment] = []
    private var speechStart: Double?
    private var microphoneSpeakerID = "me"
    private var unverified: [Range<Int>] = []
    private var duration: Double = 0
    private var microphoneLevel: Float = 0
    private var meetingLevel: Float = 0

    private func analyse(_ frame: AudioFrame) async throws {
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        let level = min(1, sqrt(frame.samples.reduce(0) { $0 + $1 * $1 } / Float(max(1, frame.samples.count))) * 5)
        if frame.isMicrophone {
            microphoneOrigin = microphoneOrigin ?? frame.time
        } else {
            remoteOrigin = remoteOrigin ?? frame.time
        }
        let origin = (frame.isMicrophone ? microphoneOrigin : remoteOrigin) ?? frame.time
        let expected = frame.isMicrophone ? microphoneOffset + microphoneSamples.count : remoteSamples
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        let position = Int(((frame.time - origin) * 16_000).rounded())
        let gap = max(
            0,
            position - expected,
        )
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        guard gap < 80_000 else {
            throw RecordingError.interrupted
        }

        let samples = Array(
            repeating: Float.zero,
            count: gap,
        ) + frame.samples.dropFirst(max(
            0,
            expected - position,
        ))
        if frame.isMicrophone {
            microphoneLevel = level
            if frame.isUnverifiedMicrophone, samples.isEmpty == false {
                unverified.append(expected ..< (expected + samples.count))
            }
            microphoneSamples.append(contentsOf: samples)
            while microphoneSamples.count >= VadManager.chunkSize {
                let chunk = Array(microphoneSamples.prefix(VadManager.chunkSize))
                microphoneSamples.removeFirst(VadManager.chunkSize)
                try await processMicrophone(
                    chunk,
                    actualCount: chunk.count,
                )
            }
        } else {
            meetingLevel = level
            remoteSamples += samples.count
            try diarizer.process(samples, at: origin + Double(expected) / SpeechModels.sampleRate)
        }
        if let transcriber {
            transcript = try await transcriber.accept(
                samples,
                isMicrophone: frame.isMicrophone,
                origin: origin,
            )
        }
    }

    private func processMicrophone(
        _ samples: [Float],
        actualCount: Int,
    ) async throws {
        let speakerID = unverified.contains { $0.overlaps(microphoneOffset ..< (microphoneOffset + actualCount)) }
            ? "unverified-microphone" : "me"
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        let boundary = (microphoneOrigin ?? 0) + Double(microphoneOffset) / 16_000
        if speakerID != microphoneSpeakerID,
           let start = speechStart
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            microphoneSegments.append(.init(
                speakerID: microphoneSpeakerID,
                start: start,
                end: boundary,
            ))
            speechStart = boundary
        }
        microphoneSpeakerID = speakerID
        let result = try await vad.processStreamingChunk(
            samples,
            state: vadState,
            config: VadSegmentationConfig(
                // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
                minSilenceDuration: 0.25,
                speechPadding: 0,
            ),
        )
        vadState = result.state
        microphoneOffset += actualCount
        unverified.removeAll { $0.upperBound <= microphoneOffset }
        if let event = result.event {
            let time = (microphoneOrigin ?? 0) + min(
                // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
                Double(event.sampleIndex) / 16_000,
                // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
                Double(microphoneOffset) / 16_000,
            )
            if event.isStart {
                speechStart = time
            } else if let start = speechStart {
                microphoneSegments.append(.init(
                    speakerID: microphoneSpeakerID,
                    start: start,
                    end: max(start, time),
                ))
                speechStart = nil
            }
        }
    }
}
