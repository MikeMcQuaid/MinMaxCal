import AppKit

/// Bridges returning to the Mac and clock, time zone or day changes into the refresh loop.
nonisolated public enum SystemChanges {
    /// Yields when the device or displays wake, the session resumes or the clock changes.
    public static var stream: AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    for name in [
                        NSWorkspace.didWakeNotification,
                        NSWorkspace.screensDidWakeNotification,
                        NSWorkspace.sessionDidBecomeActiveNotification,
                    ] {
                        group.addTask {
                            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: name) {
                                continuation.yield()
                            }
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
