import Foundation
import Speech

/// Speech assets are installed only by the explicit Download Speech Models action.
enum AppleSpeechAssets {
    static func transcriber() async throws -> SpeechTranscriber {
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-GB"))
        else {
            throw RecordingError.speechUnavailable
        }

        return SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange],
        )
    }

    static func isInstalled() async -> Bool {
        guard let module = try? await transcriber() else {
            return false
        }

        return await AssetInventory.status(forModules: [module]) == .installed
    }

    static func download(for module: SpeechTranscriber) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }
    }
}
