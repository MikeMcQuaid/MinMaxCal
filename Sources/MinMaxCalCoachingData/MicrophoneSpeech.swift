import MinMaxCalCoachingDomain

struct MicrophoneSpeech {
    // MARK: Internal

    let requiresVoiceActivity: Bool
    private(set) var segments: [SpeechSegment] = []

    mutating func observe(start: Double, end: Double, detected: Bool) {
        guard detected, start.isFinite, end.isFinite, end > start else {
            return
        }

        if let last = activity.last, start <= last.upperBound {
            activity[activity.count - 1] = last.lowerBound ..< max(last.upperBound, end)
        } else {
            activity.append(start ..< end)
        }
    }

    mutating func confirm(_ words: [TranscriptWord]) -> [TranscriptWord] {
        var confirmed = [TranscriptWord]()
        for word in words {
            guard word.start.isFinite, word.end.isFinite, word.end > word.start else {
                continue
            }
            guard word.source == .microphone else {
                confirmed.append(word)
                continue
            }

            activity.removeAll { $0.upperBound <= word.start }
            let ranges = requiresVoiceActivity ? activity : [word.start ..< word.end]
            var accepted = false
            for range in ranges {
                let start = max(word.start, range.lowerBound)
                let end = min(word.end, range.upperBound)
                guard end > start else {
                    continue
                }

                accepted = true
                if let last = segments.last, start <= last.end {
                    segments[segments.count - 1] = .init(speakerID: "me", start: last.start, end: max(last.end, end))
                } else {
                    segments.append(.init(speakerID: "me", start: start, end: end))
                }
            }
            if accepted {
                confirmed.append(word)
            }
        }
        return confirmed
    }

    // MARK: Private

    private var activity: [Range<Double>] = []
}
