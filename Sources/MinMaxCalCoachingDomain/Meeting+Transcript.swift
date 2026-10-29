import Foundation

public extension Meeting {
    /// Attributes saved words to the current speaker labels, omitting rejected microphone echo.
    var transcriptTurns: [TranscriptTurn] {
        let segments = segments.sorted { $0.start < $1.start }
        var nextSegment = 0
        var active = [SpeechSegment]()
        var turns = [TranscriptTurn]()
        for word in (transcript ?? [])
            .filter({ $0.start.isFinite && $0.end.isFinite && $0.text.isEmpty == false })
            .sorted(by: { $0.start < $1.start })
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
            let end = max(word.start + 0.01, word.end)
            while nextSegment < segments.count, segments[nextSegment].start < end {
                active.append(segments[nextSegment])
                nextSegment += 1
            }
            active.removeAll { $0.end <= word.start }
            let candidates = Set(active.filter { segment in
                segment.start < end && segment.end > word.start &&
                    (word.source == .microphone
                        ? segment.speakerID == "me" || segment.speakerID == "unverified-microphone"
                        : segment.speakerID.hasPrefix("speaker-"))
            }
            .map(\.speakerID))
            guard word.source != .microphone || candidates.isEmpty == false else {
                continue
            }

            let speakerID: String =
                if word.source == .microphone {
                    candidates == ["me"] ? "me" : "unverified-microphone"
                } else if isOneToOne == true {
                    SpeakerIdentity.scoped("speaker-1", session: RecordingSession.index(at: word.start))
                } else if candidates.count == 1,
                          let speaker = candidates.first
                // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                {
                    speaker
                } else {
                    candidates.isEmpty ? "unidentified-speaker" : "overlapping-speakers"
                }
            // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
            if let last = turns.last, last.speakerID == speakerID, word.start - last.end < 2 {
                turns[turns.count - 1].text += " " + word.text
                turns[turns.count - 1].end = max(last.end, end)
            } else {
                turns.append(.init(
                    speakerID: speakerID,
                    start: word.start,
                    end: end,
                    text: word.text,
                ))
            }
        }
        return turns
    }

    /// Renders the transcript with timestamps and current meeting-local names.
    var transcriptText: String {
        transcriptTurns.map { "[\($0.timestamp)] \(name(for: $0.speakerID)): \($0.text)" }.joined(separator: "\n\n")
    }
}
