import MinMaxCalCoachingDomain
@testable import MinMaxCalCoachingFeatures
import Testing

actor Models: SpeechModelStore {
    // MARK: Lifecycle

    init(
        ready: Bool = true,
        failDownload: Bool = false,
        holdDownload: Bool = false,
    ) {
        self.ready = ready
        self.failDownload = failDownload
        self.holdDownload = holdDownload
    }

    // MARK: Internal

    var ready: Bool
    var failDownload: Bool
    let holdDownload: Bool
    var downloads = 0
    var checks = 0

    func isReady() -> Bool {
        checks += 1
        return ready
    }

    func setReady(_ ready: Bool) {
        self.ready = ready
    }

    func allowRetry() {
        failDownload = false
    }

    func download(progress: @Sendable (String) async -> Void) async throws {
        downloads += 1
        await progress("Downloading test models…")
        if holdDownload {
            try await Task.sleep(for: .seconds(60))
        }
        if failDownload {
            throw TestError.failed
        }
        ready = true
    }
}
