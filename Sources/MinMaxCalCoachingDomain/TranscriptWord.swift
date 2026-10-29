import Foundation

public struct TranscriptWord: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        source: Source,
    ) {
        self.text = text
        self.start = start
        self.end = end
        self.source = source
    }

    // MARK: Public

    public enum Source: String, Codable, Sendable { case microphone,
                                                         system
    }

    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let source: Source
}
