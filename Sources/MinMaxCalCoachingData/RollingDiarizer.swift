import MinMaxCalCoachingDomain

/// Owned by SpeechProcessor; resets only remote inference, retaining the loaded model.
final class RollingDiarizer {
    // MARK: Lifecycle

    init(session: any DiarizationSession) {
        self.session = session
    }

    // MARK: Internal

    func process(_ samples: [Float], at time: Double) throws {
        var offset = 0
        while offset < samples.count {
            let start = time + Double(offset) / SpeechModels.sampleRate
            let index = RecordingSession.index(at: start)
            if origin == nil || index != sessionIndex {
                if origin != nil {
                    try session.finish()
                    completed = snapshot().segments
                    session.reset()
                }
                origin = start
                sessionIndex = index
            }
            let boundary = Double(index + 1) * RecordingSession.maximumDuration
            let count = min(
                samples.count - offset,
                max(1, Int(((boundary - start) * SpeechModels.sampleRate).rounded(.up))),
            )
            try session.process(Array(samples[offset ..< (offset + count)]))
            offset += count
        }
    }

    func finish() throws {
        try session.finish()
    }

    func snapshot() -> SpeechUpdate {
        let update = session.snapshot()
        return SpeechUpdate(
            segments: completed + update.segments.map { segment in
                SpeechSegment(
                    speakerID: SpeakerIdentity.scoped(segment.speakerID, session: sessionIndex),
                    start: (origin ?? 0) + segment.start,
                    end: (origin ?? 0) + segment.end,
                )
            },
            duration: (origin ?? 0) + update.duration,
            activeSpeakerIDs: update.activeSpeakerIDs.map { SpeakerIdentity.scoped($0, session: sessionIndex) },
        )
    }

    // MARK: Private

    private let session: any DiarizationSession
    private var origin: Double?
    private var sessionIndex = 0
    private var completed: [SpeechSegment] = []
}
