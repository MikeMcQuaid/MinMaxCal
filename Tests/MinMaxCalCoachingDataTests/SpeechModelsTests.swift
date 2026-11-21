import FluidAudio
import Foundation
@testable import MinMaxCalCoachingData
import Testing

@Test
func `missing models do not trigger an implicit download`() async throws {
    let directory = TestScratch.directory().appending(path: "missing-models")
    defer { try? FileManager.default.removeItem(at: directory) }
    let models = SpeechModels(directory: directory)
    #expect(await models.isReady() == false)
    do {
        _ = try await SpeechProcessor(
            transcribe: true,
            modelDirectory: directory,
        )
        Issue.record("Recording accepted missing models")
    } catch {
        #expect(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) == false)
    }
    #expect(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) == false)

    let model = directory.appending(path: Repo.lseendDihard3.folderName)
        .appending(path: SpeechModels.diarizerPath)
    try FileManager.default.createDirectory(
        at: model,
        withIntermediateDirectories: true,
    )
    try Data("incomplete download".utf8).write(to: model.appending(path: "coremldata.bin"))
    #expect(throws: (any Error).self) {
        _ = try LSEENDSession(modelDirectory: directory)
    }
    #expect(await models.isReady() == false)
    #expect(await SpeechModels(directory: directory).isReady() == false)
}

@Test
func `model storage is per user and independent of the app bundle`() {
    let support = try? FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false,
    )
    #expect(SpeechModels.defaultDirectory == support?.appending(path: "FluidAudio/Models"))
    #expect(SpeechModels().directory == SpeechModels.defaultDirectory)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MINMAXCAL_TEST_COACHING_DOWNLOADS"] == "1"))
func `explicit model setup produces a reusable cache`() async throws {
    let models = SpeechModels()
    try await models.download { _ in }
    #expect(await models.isReady())
    #expect(await SpeechModels().isReady())
}
