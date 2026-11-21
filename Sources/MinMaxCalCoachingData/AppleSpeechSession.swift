import AVFoundation
import Foundation
import MinMaxCalCoachingDomain
import Speech

actor AppleSpeechSession: SpeechSession {
    // MARK: Lifecycle

    init(source: TranscriptWord.Source) async throws {
        self.source = source
        transcriber = try await AppleSpeechAssets.transcriber()
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
            throw RecordingError.speechModelsMissing
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw RecordingError.invalidAudioFormat
        }

        converter = try SpeechInput(format: format)
        analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: .init(priority: .utility, modelRetention: .whileInUse),
        )
        try await analyzer.prepareToAnalyze(in: format)
    }

    // MARK: Internal

    nonisolated static func words(from text: AttributedString, source: TranscriptWord.Source) -> [TranscriptWord] {
        text.runs.compactMap { run in
            guard let range = run.audioTimeRange,
                  range.start.seconds.isFinite, range.end.seconds.isFinite,
                  range.duration.seconds > 0
            else {
                return nil
            }

            let word = String(text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard word.contains(where: { $0.isLetter || $0.isNumber }) else {
                return nil
            }

            return TranscriptWord(text: word, start: range.start.seconds, end: range.end.seconds, source: source)
        }
    }

    nonisolated static func stopResults(
        _ reader: Task<Void, Never>?,
        cancelReader: Bool,
        stopAnalyzer: @Sendable () async -> Void,
    ) async {
        if cancelReader {
            reader?.cancel()
        }
        await stopAnalyzer()
        await reader?.value
    }

    func start() async throws {
        try await analyzer.start(inputSequence: inputs.stream)
        results = Task {
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    guard result.isFinal else {
                        continue
                    }

                    pending.words += Self.words(from: result.text, source: source)
                }
            } catch {
                pending.failure = error
            }
        }
    }

    func append(_ samples: [Float], at time: Double) throws {
        if let failure = pending.error {
            throw failure
        }
        origin = origin ?? time
        pendingSamples += samples
        while pendingSamples.count >= Self.chunkSize {
            try enqueue(Array(pendingSamples.prefix(Self.chunkSize)))
            pendingSamples.removeFirst(Self.chunkSize)
        }
    }

    func consumeWords() -> SpeechResults {
        pending.consume()
    }

    func finish() async -> SpeechResults {
        do {
            try enqueue(pendingSamples)
            pendingSamples.removeAll()
            for input in try converter.finish() {
                try yield(input)
            }
            inputs.continuation.finish()
            let timeout = Task {
                // swiftlint:disable:next no_magic_numbers - Bound final recognition draining to 30 seconds.
                try await Task.sleep(for: .seconds(30))
                pending.timedOut = true
                await analyzer.cancelAndFinishNow()
            }
            defer { timeout.cancel() }
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            await results?.value
        } catch {
            inputs.continuation.finish()
            await Self.stopResults(results, cancelReader: false) { [analyzer] in await analyzer.cancelAndFinishNow() }
            pending.failure = error
        }
        return consumeWords()
    }

    func cancel() async {
        inputs.continuation.finish()
        await Self.stopResults(results, cancelReader: true) { [analyzer] in await analyzer.cancelAndFinishNow() }
        results = nil
    }

    // MARK: Private

    // swiftlint:disable:next no_magic_numbers - Batch recognition into 200 ms buffers.
    private static let chunkSize: Int = .init(SpeechModels.sampleRate / 5)

    private let source: TranscriptWord.Source
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let converter: SpeechInput
    private let inputs: (
        stream: AsyncThrowingStream<AnalyzerInput, any Error>,
        continuation: AsyncThrowingStream<AnalyzerInput, any Error>.Continuation,
    ) = AsyncThrowingStream<AnalyzerInput, any Error>
        // swiftlint:disable:next no_magic_numbers - At most 25.6 seconds of queued recognition audio.
        .makeStream(bufferingPolicy: .bufferingOldest(128))
    private var results: Task<Void, Never>?
    private var pending: SpeechResults = .init()
    private var pendingSamples: [Float] = []
    private var origin: Double?
    private var samplesSent = 0

    private func enqueue(_ samples: [Float]) throws {
        guard let input = try converter.input(
            samples: samples,
            at: (origin ?? 0) + Double(samplesSent) / SpeechModels.sampleRate,
        ) else {
            return
        }

        samplesSent += samples.count
        try yield(input)
    }

    private func yield(_ input: AnalyzerInput) throws {
        if case .dropped = inputs.continuation.yield(input) {
            throw RecordingError.audioOverrun
        }
    }
}
