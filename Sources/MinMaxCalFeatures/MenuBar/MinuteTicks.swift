import Foundation

nonisolated enum MinuteTicks {
    // MARK: Internal

    static func stream(clock: @escaping @Sendable () -> Date) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                while Task.isCancelled == false {
                    let now = clock().timeIntervalSinceReferenceDate
                    let nextMinute = (floor(now / secondsPerMinute) + 1) * secondsPerMinute
                    do {
                        try await Task.sleep(for: .seconds(nextMinute - now), tolerance: .seconds(tolerance))
                    } catch {
                        return
                    }
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Private

    private static let secondsPerMinute: TimeInterval = 60
    /// Room for the system to coalesce the wake-up with others; a tolerance only ever lands late,
    /// never before the boundary.
    private static let tolerance: TimeInterval = 5
}
