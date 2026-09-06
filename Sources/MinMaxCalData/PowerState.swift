import Foundation
import IOKit.ps
import notify

/// Reports whether background work should slow down, without polling the battery.
public enum PowerState {
    // MARK: Public

    /// Yields the initial state, then changes to battery power or Low Power Mode.
    public static var changes: AsyncStream<Bool> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            var token: Int32 = 0
            let status = notify_register_dispatch(kIOPSNotifyPowerSource, &token, .main) { _ in
                continuation.yield(isConstrained)
            }
            let task = Task {
                let notifications = NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange)
                for await _ in notifications {
                    continuation.yield(isConstrained)
                }
            }
            continuation.yield(isConstrained)
            let registration = token
            continuation.onTermination = { _ in
                task.cancel()
                if status == NOTIFY_STATUS_OK {
                    notify_cancel(registration)
                }
            }
        }
    }

    // MARK: Private

    private static var isConstrained: Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
            || IOPSGetTimeRemainingEstimate() != kIOPSTimeRemainingUnlimited
    }
}
