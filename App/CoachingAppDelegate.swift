import AppKit
import MinMaxCalAgenda
import MinMaxCalCoachingFeatures

final class CoachingAppDelegate: NSObject, NSApplicationDelegate {
    var coaching: CoachingController?
    var agenda: AgendaModel?

    func respondToMeeting(_ id: String, recordImmediately: Bool) async {
        guard let coaching, coaching.enabled, let model = coaching.model else {
            return
        }

        await agenda?.rebuild()
        await coaching.waitForAgenda()
        await model.refreshCalendar()
        guard coaching.enabled, model.phase == .idle,
              let meeting = model.calendarMeetings.first(where: { $0.id == id }),
              meeting.canPrompt, meeting.start <= .now, let end = meeting.end, end > .now
        else {
            return
        }

        if recordImmediately == false {
            NSApp.activate()
            let prompt = NSAlert()
            prompt.messageText = "Record “\(meeting.title)”?"
            prompt.informativeText = "Capture your microphone and meeting audio for local coaching and a transcript."
            prompt.addButton(withTitle: "Record")
            prompt.addButton(withTitle: "Not Now")
            guard prompt.runModal() == .alertFirstButtonReturn else {
                return
            }
        }
        guard coaching.enabled else {
            return
        }

        coaching.showingMeeting = true
        await agenda?.rebuild()
        await coaching.waitForAgenda()
        guard coaching.enabled else {
            return
        }

        if await model.recordCalendarMeeting(id) == false {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Could not start this meeting"
            alert.informativeText = model.error ?? "Open the agenda to check speech-model setup."
            alert.runModal()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = coaching?.model,
              model.phase != .idle || model.modelState == .downloading || model.modelState == .checking
        else {
            return .terminateNow
        }

        Task {
            await model.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
