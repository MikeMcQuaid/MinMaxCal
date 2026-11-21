import Foundation
@testable import MinMaxCalCoachingData
import MinMaxCalCoachingDomain
import Synchronization
import Testing

@Test(arguments: [false, true])
func `failure recovery drains published results while teardown cancels the reader`(cancelReader: Bool) async {
    let word = TranscriptWord(text: "Hello", start: 1, end: 2, source: .microphone)
    let published = AsyncThrowingStream<TranscriptWord, any Error>.makeStream()
    let released = AsyncStream<Void>.makeStream()
    let received = Mutex(SpeechResults())
    published.continuation.yield(word)
    let reader = Task {
        for await _ in released.stream {
            break
        }
        do {
            for try await result in published.stream {
                try Task.checkCancellation()
                received.withLock { $0.words.append(result) }
            }
        } catch {
            received.withLock { $0.failure = error }
        }
    }
    await AppleSpeechSession.stopResults(reader, cancelReader: cancelReader) {
        published.continuation.finish(throwing: RecordingError.interrupted)
        released.continuation.finish()
    }
    #expect(reader.isCancelled == cancelReader)
    #expect(received.withLock { $0.words } == (cancelReader ? [] : [word]))
    if cancelReader == false {
        #expect(received.withLock { $0.error as? RecordingError } == .interrupted)
    }
}
