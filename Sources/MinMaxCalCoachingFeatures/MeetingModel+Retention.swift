import Foundation
import MinMaxCalCoachingDomain

extension MeetingModel {
    func refreshHistory() async {
        guard isEnabled, Task.isCancelled == false else {
            return
        }

        let retention = meetingRetention
        do {
            let saved = try await store.load(
                meetingRetention: retention,
                preserving: phase == .idle ? nil : current?.id,
            )
            guard isEnabled, Task.isCancelled == false, retention == meetingRetention else {
                return
            }

            meetings = saved
            if phase == .idle, let current {
                self.current = current.hasExpired(retention: retention, at: .now)
                    ? nil : saved.first { $0.id == current.id } ?? current
            }
            if selected == nil {
                selectedID = nil
            }
            var expiring = saved.filter { $0.id != current?.id }
            if phase == .idle, let current {
                expiring.append(current)
            }
            retentionTask?.cancel()
            if let expiry = expiring.map({ $0.expiry(retention: retention) })
                .min()
            // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
            {
                retentionTask = Task {
                    do {
                        // swiftlint:disable:next no_magic_numbers - Expiry can tolerate five seconds of delay.
                        try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow)), tolerance: .seconds(5))
                        await refreshHistory()
                    } catch {
                        return
                    }
                }
            }
        } catch {
            self.error = "Could not load meeting history: \(error.localizedDescription)"
        }
    }
}
