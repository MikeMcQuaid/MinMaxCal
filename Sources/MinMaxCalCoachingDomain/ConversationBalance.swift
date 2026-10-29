import Foundation

public struct ConversationBalance: Sendable {
    // MARK: Lifecycle

    public init(
        meeting: Meeting,
        targetShare: Double,
        turnLimit: TimeInterval,
    ) {
        var recent = meeting
        // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
        let start = max(0, meeting.duration - 300)
        // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
        recent.duration = min(300, meeting.duration)
        recent.segments = meeting.segments.compactMap { segment in
            let end = min(meeting.duration, segment.end)
            guard end > max(start, segment.start) else {
                return nil
            }

            return SpeechSegment(
                speakerID: segment.speakerID,
                start: max(start, segment.start) - start,
                end: end - start,
            )
        }
        let stats = MeetingStatistics(meeting: recent)
        recentShare = stats.speakers.first { $0.id == "me" }?.speakingShare ?? 0
        currentTurn = MeetingStatistics(meeting: meeting).speakers.first { $0.id == "me" }?.currentTurn ?? 0
        // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
        let enoughSpeech = stats.speakers.reduce(0) { $0 + $1.speakingTime } >= 30
        isReliable = recent.hasUnverifiedSpeech == false
        if isReliable == false {
            cue = "Speaker attribution uncertain. Check the meeting audio."
            needsRoom = false
        } else if currentTurn >= turnLimit {
            cue = "Finish your thought, then leave a pause."
            needsRoom = true
        } else if enoughSpeech,
                  recentShare > targetShare
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            cue = "Make room for others. Ask a question, then listen."
            needsRoom = true
        } else {
            cue = enoughSpeech ? "There’s room to listen. Let the next voice in." :
                "Listen first. Say what matters. Leave a pause."
            needsRoom = false
        }
    }

    // MARK: Public

    public let recentShare: Double
    public let currentTurn: TimeInterval
    public let cue: String
    public let needsRoom: Bool
    public let isReliable: Bool
}
