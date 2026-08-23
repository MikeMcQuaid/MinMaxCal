import Foundation
import Synchronization

nonisolated final class AdjustableClock: Sendable {
    // MARK: Internal

    var now: Date {
        get { time.withLock { $0 } }
        set { time.withLock { $0 = newValue } }
    }

    func read() -> Date {
        now
    }

    // MARK: Private

    private let time: Mutex = .init(Fixtures.now)
}
