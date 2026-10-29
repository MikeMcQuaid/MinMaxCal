import MinMaxCalCoachingDomain

protocol DiarizationSession: AnyObject {
    func process(_ samples: [Float]) throws
    func finish() throws
    func reset()
    func snapshot() -> SpeechUpdate
}
