import Foundation

// MARK: - SpeechSegment

// MARK: - Meeting

public struct Meeting: Codable, Equatable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        title: String,
        startedAt: Date = .now,
    ) {
        id = UUID()
        self.title = title
        self.startedAt = startedAt
        duration = 0
        segments = []
        names = ["me": "You"]
        isComplete = false
        transcript = []
    }

    // MARK: Public

    public var id: UUID
    public var title: String
    public var startedAt: Date
    public var duration: TimeInterval
    public var segments: [SpeechSegment]
    public var names: [String: String]
    public var isComplete: Bool
    public var notice: String?
    public var endedAt: Date?
    // swiftlint:disable:next discouraged_optional_collection - Older saved summaries omit this field.
    public var transcript: [TranscriptWord]?
    // swiftlint:disable:next discouraged_optional_collection - Older saved summaries omit this field.
    public var calendarParticipantNames: [String]?
    // swiftlint:disable:next discouraged_optional_boolean - Legacy summary compatibility.
    public var isOneToOne: Bool?

    public var hasUnverifiedSpeech: Bool {
        segments.contains { $0.speakerID == "unverified-microphone" && $0.end > $0.start }
    }

    public func name(for speakerID: String) -> String {
        if speakerID == "unverified-microphone" {
            return "Unverified microphone"
        }
        if speakerID == "unidentified-speaker" {
            return "Unidentified speaker"
        }
        if speakerID == "overlapping-speakers" {
            return "Overlapping speakers"
        }
        return names[speakerID] ?? SpeakerIdentity.title(for: speakerID)
    }
}

// MARK: - SpeechUpdate

// MARK: - MeetingRecorder

// MARK: - MeetingStore
