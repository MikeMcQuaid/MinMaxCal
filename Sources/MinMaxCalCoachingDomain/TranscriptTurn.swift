import Foundation

public struct TranscriptTurn: Equatable, Sendable {
    public let speakerID: String
    public let start: TimeInterval
    public var end: TimeInterval
    public var text: String

    public var timestamp: String {
        let seconds = Int(max(0, start))
        // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
        return unsafe String(format: "%02d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60)
    }
}
