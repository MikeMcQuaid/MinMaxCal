@unsafe @preconcurrency import AVFoundation
import FluidAudio
import MinMaxCalCoachingDomain

actor LiveTranscriber {
    // MARK: Lifecycle

    // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
    init(modelDirectory: URL = SpeechModels.defaultDirectory) async throws {
        let directory = modelDirectory.appending(path: Repo.parakeetUnified.folderName)
        try await microphone.loadModels(from: directory)
        try Task.checkCancellation()
        try await system.loadModels(from: directory)
    }

    // MARK: Internal

    func accept(
        _ samples: [Float],
        isMicrophone: Bool,
        origin: Double,
    ) async throws -> [TranscriptWord] {
        guard samples.isEmpty == false else {
            return words
        }
        guard let format = AVAudioFormat(
                  // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
                  standardFormatWithSampleRate: 16_000,
                  channels: 1,
              ),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(samples.count),
              ),
              let destination = unsafe buffer.floatChannelData?[0]
        else {
            throw RecordingError.invalidAudioFormat
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in unsafe destination.update(
            // swiftlint:disable:next force_unwrapping - Pinned model path or non-empty buffer.
            from: source.baseAddress!,
            count: source.count,
        )
        }
        let manager = isMicrophone ? microphone : system
        if isMicrophone {
            microphoneOrigin = microphoneOrigin ?? origin
        } else {
            systemOrigin = systemOrigin ?? origin
        }
        try await manager.appendAudio(buffer)
        try await manager.processBufferedAudio()
        let tokens = await manager.consumeTokenTimings()
        guard tokens.isEmpty == false else {
            return words
        }

        if isMicrophone {
            microphoneTokens += tokens
        } else {
            systemTokens += tokens
        }
        updateWords()
        return words
    }

    func finish() async throws -> [TranscriptWord] {
        if microphoneOrigin != nil {
            _ = try await microphone.finish()
            microphoneTokens += await microphone.consumeTokenTimings()
        }
        if systemOrigin != nil {
            _ = try await system.finish()
            systemTokens += await system.consumeTokenTimings()
        }
        updateWords()
        return words
    }

    // MARK: Private

    private let microphone: StreamingUnifiedAsrManager = .init()
    private let system: StreamingUnifiedAsrManager = .init()
    private var microphoneTokens: [TokenTiming] = []
    private var systemTokens: [TokenTiming] = []
    private var microphoneOrigin: Double?
    private var systemOrigin: Double?
    private var words: [TranscriptWord] = []

    private func updateWords() {
        words = buildWordTimings(from: microphoneTokens).map { word in
            TranscriptWord(
                text: word.word,
                start: (microphoneOrigin ?? 0) + word.startTime,
                end: (microphoneOrigin ?? 0) + word.endTime,
                source: .microphone,
            )
        } + buildWordTimings(from: systemTokens).map { word in
            TranscriptWord(
                text: word.word,
                start: (systemOrigin ?? 0) + word.startTime,
                end: (systemOrigin ?? 0) + word.endTime,
                source: .system,
            )
        }
    }
}
