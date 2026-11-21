@testable import MinMaxCalCoachingData

actor SpeechSessionFixture: SpeechSession {
    // MARK: Lifecycle

    init(results: SpeechResults, appendError: any Error?) {
        self.results = results
        self.appendError = appendError
    }

    // MARK: Internal

    func start() {
        // This fixture starts with prepared results.
    }

    func publish(_ results: SpeechResults) {
        self.results = results
    }

    func append(_: [Float], at _: Double) throws {
        if let appendError {
            throw appendError
        }
    }

    func consumeWords() -> SpeechResults {
        results.consume()
    }

    func finish() -> SpeechResults {
        results.consume()
    }

    func cancel() {
        // This fixture allocates no analyser resources.
    }

    // MARK: Private

    private var results: SpeechResults
    private let appendError: any Error?
}
