public protocol SpeechModelStore: Sendable {
    func isReady() async -> Bool
    func download(progress: @Sendable (String) async -> Void) async throws
}
