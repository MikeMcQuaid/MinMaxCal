import Foundation

@preconcurrency
@MainActor
public protocol MeetingRecorder: AnyObject {
    func start(
        reduceSpeakerEcho: Bool
    ) async throws -> AsyncThrowingStream<
        SpeechUpdate,
        any Error,
    >
    func stop() async
}
