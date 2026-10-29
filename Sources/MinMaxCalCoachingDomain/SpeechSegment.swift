import Foundation

public struct SpeechSegment: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        speakerID: String,
        start: TimeInterval,
        end: TimeInterval,
    ) {
        self.speakerID = speakerID
        self.start = start
        self.end = end
    }

    // MARK: Public

    public let speakerID: String
    public let start: TimeInterval
    public let end: TimeInterval
}
