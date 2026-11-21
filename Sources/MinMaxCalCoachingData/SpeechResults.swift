import MinMaxCalCoachingDomain

struct SpeechResults {
    var words: [TranscriptWord] = []
    var failure: any Error?
    var timedOut = false

    var error: any Error? {
        if timedOut {
            RecordingError.recognitionTimedOut
        } else {
            failure
        }
    }

    mutating func consume() -> Self {
        defer { words.removeAll(keepingCapacity: true) }
        return self
    }
}
