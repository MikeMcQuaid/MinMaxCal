import MinMaxCalCoachingDomain

package extension MeetingModel {
    var canRestart: Bool {
        canStart && selected?.isComplete == false
    }

    func restart() {
        guard canRestart, let meeting = selected else {
            return
        }

        selectCalendarMeeting(nil)
        startRecording(restarting: meeting)
    }
}
