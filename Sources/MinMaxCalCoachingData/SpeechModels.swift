import FluidAudio
import Foundation
import MinMaxCalCoachingDomain
import Speech

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
            _ = try LSEENDSession(modelDirectory: directory)
            return await AppleSpeechAssets.isInstalled()
        } catch {
            return false
        }
    }

    @preconcurrency
    public func download(progress: @Sendable (String) async -> Void) async throws {
        try await download(progress: progress, transcriber: AppleSpeechAssets.transcriber)
    }

    // MARK: Internal

    static let sampleRate = 16_000.0

    static let diarizerPath = """
    \(Repo.lseendDihard3.subPath ?? "")/\
    \(ModelNames.LSEEND.Variant.dihard3.fileName(forStep: .step100ms))
    """

    func download(
        progress: @Sendable (String) async -> Void,
        transcriber: @Sendable () async throws -> SpeechTranscriber,
    ) async throws {
        let module = try await transcriber()
        await progress("Downloading remote-speaker model (1 of 2)…")
        try await ModelHub.download(
            .lseendDihard3,
            subdirectory: Self.diarizerPath,
            to: directory.appending(path: Repo.lseendDihard3.folderName),
        )
        try Task.checkCancellation()
        await progress("Downloading Apple's English speech model (2 of 2)…")
        try await AppleSpeechAssets.download(for: module)
        try Task.checkCancellation()
        await progress("Checking downloaded models…")
    }

    func processor(reduceSpeakerEcho: Bool) async throws -> SpeechProcessor {
        try await SpeechProcessor(reduceSpeakerEcho: reduceSpeakerEcho, transcribe: true, modelDirectory: directory)
    }
}
