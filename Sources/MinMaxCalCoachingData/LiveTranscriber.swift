actor LiveTranscriber {
    // MARK: Lifecycle

    init() async throws {
        microphone = try await AppleSpeechSession(source: .microphone)
        do {
            system = try await AppleSpeechSession(source: .system)
        } catch {
            await microphone.cancel()
            throw error
        }
        do {
            try await microphone.start()
            try await system.start()
        } catch {
            await microphone.cancel()
            await system.cancel()
            throw error
        }
    }

    // periphery:ignore - Dependency injection for model-free failure tests.
    init(microphone: any SpeechSession, system: any SpeechSession) {
        self.microphone = microphone
        self.system = system
    }

    // MARK: Internal

    func accept(_ samples: [Float], isMicrophone: Bool, time: Double) async -> SpeechResults {
        var failure: any Error?
        do {
            try await (isMicrophone ? microphone : system).append(samples, at: time)
        } catch {
            failure = error
        }
        let microphoneWords = await microphone.consumeWords()
        let systemWords = await system.consumeWords()
        return SpeechResults(
            words: microphoneWords.words + systemWords.words,
            failure: failure ?? microphoneWords.error ?? systemWords.error,
        )
    }

    func finish() async -> SpeechResults {
        async let microphoneWords = microphone.finish()
        async let systemWords = system.finish()
        let (microphoneResult, systemResult) = await (microphoneWords, systemWords)
        return SpeechResults(
            words: microphoneResult.words + systemResult.words,
            failure: microphoneResult.error ?? systemResult.error,
        )
    }

    func cancel() async {
        await microphone.cancel()
        await system.cancel()
    }

    // MARK: Private

    private let microphone: any SpeechSession
    private let system: any SpeechSession
}
