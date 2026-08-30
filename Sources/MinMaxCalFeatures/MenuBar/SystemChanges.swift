import AppKit

/// Bridges the system's own changes into the refresh loop: waking from sleep, the clock being set
/// (as the network time service does after a wake), a new time zone (as landing does) and a new day.
nonisolated public enum SystemChanges {
    /// Yields once per wake, clock change, time zone change or day change.
    public static var stream: AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        let wakes = NSWorkspace.shared
                            .notificationCenter
                            .notifications(named: NSWorkspace.didWakeNotification)
                        for await _ in wakes {
                            continuation.yield()
                        }
                    }
                    for name in [
                        Notification.Name.NSSystemClockDidChange,
                        .NSSystemTimeZoneDidChange,
                        .NSCalendarDayChanged,
                    ] {
                        group.addTask {
                            for await _ in NotificationCenter.default.notifications(named: name) {
                                continuation.yield()
                            }
                        }
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
