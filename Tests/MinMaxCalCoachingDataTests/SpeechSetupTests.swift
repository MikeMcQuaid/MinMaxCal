import Foundation
@testable import MinMaxCalCoachingData
import Synchronization
import Testing

@Test
func `unsupported Apple speech fails before any download stage`() async {
    let directory = TestScratch.directory().appending(path: "unsupported-speech")
    let progress = Mutex<[String]>([])
    await #expect(throws: RecordingError.speechUnavailable) {
        try await SpeechModels(directory: directory).download(
            progress: { message in progress.withLock { $0.append(message) } },
            transcriber: { throw RecordingError.speechUnavailable },
        )
    }
    #expect(progress.withLock { $0.isEmpty })
    #expect(FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) == false)
}
