import Foundation
import MinMaxCalCoachingDomain

extension MeetingModel {
    package func start() {
        startRecording(restarting: nil)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length - One audio capture lifecycle.
    func startRecording(restarting meeting: Meeting?) {
        guard canStart else {
            return
        }

        phase = .preparing
        error = nil
        current = nil
        hasMeetingAudio = false
        let reduceSpeakerEcho = reduceSpeakerEcho
        // swiftlint:disable:next closure_body_length - One migrated audio operation.
        recordingTask = Task {
            do {
                await updateCalendarPrompts()
                if notifier != nil {
                    await enableNotifications()
                }
                try Task.checkCancellation()
                await refreshCalendar()
                try Task.checkCancellation()
                let meetingTitle = (meeting?.title ?? title).trimmingCharacters(in: .whitespacesAndNewlines)
                let calendarMeeting = calendarMeeting
                let myName = (meeting?.names["me"] ?? myName).trimmingCharacters(in: .whitespacesAndNewlines)
                let otherName = (meeting.map { $0.isOneToOne == true ? $0.names["speaker-1"] ?? "" : "" }
                    ?? otherParticipantName).trimmingCharacters(in: .whitespacesAndNewlines)
                let updates = try await recorder.start(
                    reduceSpeakerEcho: reduceSpeakerEcho
                )
                try Task.checkCancellation()
                current = Meeting(title: meetingTitle.isEmpty ? "Meeting" : meetingTitle)
                current?.calendarParticipantNames = meeting == nil
                    ? calendarMeeting?.participantNames : meeting?.calendarParticipantNames
                if myName.isEmpty == false {
                    current?.names["me"] = myName
                }
                current?.isOneToOne = otherName.isEmpty == false
                if otherName.isEmpty == false {
                    current?.names["speaker-1"] = otherName
                }
                let speakerID: (String) -> String = { identifier in
                    otherName.isEmpty ? identifier : SpeakerIdentity.oneToOne(identifier)
                }
                selectedID = current?.id
                phase = .recording
                var reminder = CoachingReminder()
                notifier?.clear()
                var savedAt: Double = -15
                for try await update in updates {
                    current?.duration = update.duration
                    current?.segments = update.segments.map { segment in
                        SpeechSegment(
                            speakerID: speakerID(segment.speakerID),
                            start: segment.start,
                            end: segment.end,
                        )
                    }
                    current?.transcript = update.transcript
                    microphoneLevel = update.microphoneLevel
                    meetingLevel = update.meetingLevel
                    activeSpeakerIDs = Array(Set(update.activeSpeakerIDs.map(speakerID))).sorted()
                    hasMeetingAudio = update.hasMeetingAudio
                    if phase == .recording,
                       let current
                    // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                    {
                        let balance = ConversationBalance(
                            meeting: current,
                            targetShare: targetShare,
                            turnLimit: turnLimit,
                        )
                        if reminder.shouldNotify(
                               needsRoom: balance.needsRoom,
                               at: update.duration,
                           ),
                           notificationsAllowed
                        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                        {
                            do {
                                try await notifier?.notify(balance.cue)
                            } catch {
                                notificationMessage =
                                    "Could not show the target reminder: \(error.localizedDescription)"
                            }
                        }
                    }
                    // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
                    if update.duration - savedAt >= 15,
                       let current
                    // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                    {
                        try await store.save(current)
                        savedAt = update.duration
                    }
                }
                current?.isComplete = true
            } catch is CancellationError {
                current?.notice = "Recording cancelled."
            } catch {
                self.error = error.localizedDescription
                current?.notice = error.localizedDescription
                if current == nil {
                    modelState = await speechModels.isReady() ? .ready : .missing
                }
            }
            await recorder.stop()
            notifier?.clear()
            current?.endedAt = .now
            if let current {
                do {
                    try await store.save(current)
                    meetings.removeAll { $0.id == current.id }
                    meetings.insert(
                        current,
                        at: 0,
                    )
                } catch {
                    self.error = """
                    Could not save the summary: \(error.localizedDescription). It remains available in this window to \
                    copy.
                    """
                }
            }
            microphoneLevel = 0
            meetingLevel = 0
            activeSpeakerIDs = []
            if let current {
                selectedID = current.id
            }
            phase = .idle
            await refreshHistory()
            recordingTask = nil
            await refreshCalendar()
        }
    }

    /// Cancels setup or drains capture and saves the resulting summary.
    public func stop() async {
        downloadTask?.cancel()
        await downloadTask?.value
        guard phase != .idle else {
            return
        }

        if phase == .preparing {
            recordingTask?.cancel()
        }
        phase = .stopping
        await recorder.stop()
        await recordingTask?.value
    }
}
