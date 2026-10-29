import Foundation

public struct SpeechUpdate: Sendable {
    // MARK: Lifecycle

    public init(
        segments: [SpeechSegment],
        duration: TimeInterval,
        microphoneLevel: Float = 0,
        meetingLevel: Float = 0,
        activeSpeakerIDs: [String] = [],
        hasMeetingAudio: Bool = false,
        transcript: [TranscriptWord] = [],
    ) {
        self.segments = segments
        self.duration = duration
        self.microphoneLevel = microphoneLevel
        self.meetingLevel = meetingLevel
        self.activeSpeakerIDs = activeSpeakerIDs
        self.hasMeetingAudio = hasMeetingAudio
        self.transcript = transcript
    }

    // MARK: Public

    public var segments: [SpeechSegment]
    public var duration: TimeInterval
    public var microphoneLevel: Float
    public var meetingLevel: Float
    public var activeSpeakerIDs: [String]
    public var hasMeetingAudio: Bool
    public var transcript: [TranscriptWord]
}
