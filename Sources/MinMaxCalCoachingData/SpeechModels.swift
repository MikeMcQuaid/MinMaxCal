import FluidAudio
import Foundation
import MinMaxCalCoachingDomain

public actor SpeechModels: SpeechModelStore {
    // MARK: Lifecycle

    public init(directory: URL = defaultDirectory) {
        self.directory = directory
    }

    // MARK: Public

    /// Keep FluidAudio's existing per-user cache, including across app rebuilds.
    public static let defaultDirectory = URL.applicationSupportDirectory.appending(path: "FluidAudio/Models")

    nonisolated public let directory: URL

    public func isReady() async -> Bool {
        guard Task.isCancelled == false else {
            return false
        }

        do {
            _ = try await processor(reduceSpeakerEcho: true)
            return true
        } catch {
            return false
        }
    }

    @preconcurrency
    public func download(progress: @Sendable (String) async -> Void) async throws {
        await progress("Downloading voice detection model (1 of 4)…")
        try await ModelHub.download(
            .vad,
            to: directory,
        )
        try Task.checkCancellation()
        await progress("Downloading speaker identification model (2 of 4)…")
        try await ModelHub.download(
            .lseendDihard3,
            subdirectory: Self.diarizerPath,
            to: directory.appending(path: Repo.lseendDihard3.folderName),
        )
        try Task.checkCancellation()
        await progress("Downloading echo reduction model (3 of 4)…")
        try await ModelHub.download(
            .localVqe,
            to: directory,
            variant: ModelNames.LocalVQE.variantKey(
                variant: LocalVqeConfig.default.variant,
                chunk: LocalVqeConfig.default.chunk,
            ),
        )
        try Task.checkCancellation()
        await progress("Downloading transcription model (4 of 4)…")
        try await ModelHub.download(
            .parakeetUnified,
            to: directory,
            additionalModelNames: [ModelNames.ParakeetUnified.streamingEncoderFile(precision: .int8)],
        )
        try Task.checkCancellation()
        await progress("Checking downloaded models…")
    }

    // MARK: Internal

    static let sampleRate = 16_000.0

    static let diarizerPath = """
    \(Repo.lseendDihard3.subPath ?? "")/\
    \(ModelNames.LSEEND.Variant.dihard3.fileName(forStep: .step100ms))
    """

    func processor(reduceSpeakerEcho: Bool) async throws -> SpeechProcessor {
        try await SpeechProcessor(reduceSpeakerEcho: reduceSpeakerEcho, transcribe: true, modelDirectory: directory)
    }
}
