protocol SpeechSession: Actor {
    func start() async throws
    func append(_ samples: [Float], at time: Double) async throws
    func consumeWords() async -> SpeechResults
    func finish() async -> SpeechResults
    func cancel() async
}
