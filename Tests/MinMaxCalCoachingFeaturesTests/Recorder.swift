import Foundation
import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

final class Recorder: MeetingRecorder {
    var continuation: AsyncThrowingStream<
        SpeechUpdate,
        any Error,
    >.Continuation?
    var failStart = false
    var starts = 0
    var holdStart = false
    // swiftlint:disable:next discouraged_optional_boolean - Legacy summary compatibility.
    var reduceSpeakerEcho: Bool?
    var finalUpdate: SpeechUpdate?

    func start(
        reduceSpeakerEcho: Bool
    ) async throws -> AsyncThrowingStream<
        SpeechUpdate,
        any Error,
    > {
        starts += 1
        self.reduceSpeakerEcho = reduceSpeakerEcho
        if holdStart {
            try await Task.sleep(for: .seconds(60))
        }
        if failStart {
            throw TestError.failed
        }
        return AsyncThrowingStream { continuation = $0 }
    }

    func stop() {
        if let finalUpdate {
            continuation?.yield(finalUpdate)
        }
        continuation?.finish()
    }
}
