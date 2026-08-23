import AppKit

/// Bridges `NSWorkspace.didWakeNotification` into the refresh loop.
nonisolated public enum WakeNotifications {
    /// Yields once per wake from sleep.
    public static var stream: AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                let notifications = NSWorkspace.shared
                    .notificationCenter
                    .notifications(named: NSWorkspace.didWakeNotification)
                for await _ in notifications {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
