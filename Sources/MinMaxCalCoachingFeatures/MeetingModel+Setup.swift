import Foundation
import MinMaxCalCoachingDomain

package extension MeetingModel {
    func deactivate() async {
        isEnabled = false
        retentionTask?.cancel()
        await retentionTask?.value
        retentionTask = nil
        await stop()
        notifier?.clear()
        await updateCalendarPrompts()
    }

    func downloadSpeechModels() {
        guard isEnabled, phase == .idle,
              modelState == .missing
        else {
            return
        }

        modelState = .downloading
        error = nil
        downloadStatus = "Preparing download…"
        downloadTask = Task {
            do {
                try await speechModels.download { status in
                    await MainActor.run { self.downloadStatus = status }
                }
                try Task.checkCancellation()
                guard await speechModels.isReady() else {
                    throw CocoaError(.fileReadCorruptFile)
                }

                try Task.checkCancellation()
                modelState = .ready
            } catch {
                modelState = .missing
                if Task.isCancelled == false {
                    self.error = "Could not prepare speech models: \(error.localizedDescription). Retry the download."
                }
            }
            downloadTask = nil
        }
    }

    func cancelModelDownload() {
        downloadTask?.cancel()
    }

    func load() async {
        guard isEnabled, Task.isCancelled == false else {
            return
        }

        await refreshHistory()
        guard isEnabled, Task.isCancelled == false else {
            return
        }

        modelState = .checking
        let ready = await speechModels.isReady()
        modelState = ready ? .ready : .missing
        await refreshCalendar()
    }

    func enableNotifications() async {
        guard isEnabled else {
            return
        }

        do {
            notificationsAllowed = try await notifier?
                .requestAuthorization() ?? false
            notificationMessage = notificationsAllowed ? nil : """
            Notifications are off. Allow MinMaxCal in System Settings → Notifications to receive reminders.
            """
        } catch {
            notificationsAllowed = false
            notificationMessage = "Could not enable notifications: \(error.localizedDescription)"
        }
        await updateCalendarPrompts()
    }
}
