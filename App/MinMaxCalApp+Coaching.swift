import MinMaxCalAgenda
import MinMaxCalCoachingData
import MinMaxCalCoachingFeatures
import MinMaxCalFeatures

extension MinMaxCalApp {
    func makeCoaching(agenda: AgendaModel, takeover: TakeoverModel, sync: CalendarSyncModel) -> CoachingController {
        let coachingController = CoachingController(makeModel: { [weak delegate = delegate] in
            let notifier = TargetNotifications()
            let model = MeetingModel(
                recorder: SystemAudioRecorder(),
                store: JSONMeetingStore(),
                speechModels: SpeechModels(),
                calendar: AgendaMeetingCalendar(agenda: agenda),
                defaults: .standard,
                notifier: notifier,
            )
            notifier.onMeetingResponse = { [weak delegate] id, recordImmediately in
                await delegate?.respondToMeeting(id, recordImmediately: recordImmediately)
            }
            return model
        })
        delegate.coaching = coachingController
        delegate.agenda = agenda
        takeover.recordingEnabled = { coachingController.enabled && coachingController.model?.phase == .idle }
        takeover.recordingReady = { coachingController.canRecord }
        takeover.recordsJoinsByDefault = { coachingController.recordOnJoin }
        takeover.onRecord = { item in Task {
            await agenda.rebuild()
            await coachingController.record(item)
        }
        }
        agenda.onRebuild = { agenda, now in
            takeover.schedule(agenda: agenda, now: now)
            sync.requestRefresh()
            coachingController.agendaChanged(at: now)
        }
        agenda.onTick = { agenda, now in
            takeover.tick(agenda: agenda, now: now)
            coachingController.tick(at: now)
        }
        return coachingController
    }
}
