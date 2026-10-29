import Foundation
import MinMaxCalCoachingDomain

public extension MeetingModel {
    /// Projects the existing agenda without requesting additional calendar access.
    func refreshCalendar(
        requestAccess: Bool = false,
        at date: Date = .now,
    ) async {
        guard isEnabled,
              let calendar,
              isReadingCalendar == false
        else {
            return
        }

        calendarNow = date
        isReadingCalendar = true
        defer { isReadingCalendar = false }
        do {
            let events = try await calendar.meetings(
                around: date,
                requestAccess: requestAccess,
            )
            try Task.checkCancellation()
            hasCalendarAccess = true
            calendarMeetings = CalendarMeeting.inferred(
                from: events,
                at: date,
            )
            if phase == .idle || phase == .preparing,
               calendarChoiceIsManual == false || (calendarMeetingID != nil && calendarMeeting == nil)
            // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
            {
                calendarChoiceIsManual = false
                calendarMeetingID = CalendarMeeting.suggestions(
                    from: calendarMeetings,
                    at: date,
                )
                .first?
                .id
            }
            calendarMessage = nil
        } catch {
            hasCalendarAccess = false
            calendarMeetings = []
            if calendarMeetingID != nil {
                calendarChoiceIsManual = false
            }
            calendarMeetingID = nil
            calendarMessage = error.localizedDescription
        }
        if phase == .idle || phase == .preparing {
            applyCalendarTitle()
        }
        if requestAccess,
           hasCalendarAccess
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            await enableNotifications()
        }
        await updateCalendarPrompts(at: date)
    }

    /// Selects a meeting title and invitees without starting capture.
    func useCalendarMeeting(_ id: String) {
        guard phase == .idle,
              let meeting = calendarMeetings.first(where: { $0.id == id })
        else {
            return
        }

        selectedID = nil
        selectCalendarMeeting(id)
        title = meeting.title
    }

    /// Revalidates an occurrence before honouring an explicit Record choice.
    func recordCalendarMeeting(
        _ id: String,
        at date: Date = .now,
        fromPrompt: Bool = true,
    ) async -> Bool {
        guard phase == .idle else {
            return false
        }
        guard isReadingCalendar == false else {
            error = "Calendar is still loading. Open the menu bar panel and try again."
            return false
        }

        await refreshCalendar(at: date)
        guard let meeting = calendarMeetings.first(where: { $0.id == id }),
              fromPrompt == false || (meeting.canPrompt && meeting.start <= date)
        else {
            error = "This meeting is no longer available. Check upcoming meetings in the menu bar panel."
            return false
        }

        useCalendarMeeting(id)
        guard canStart else {
            error = "Download speech models in Settings → Coaching before recording."
            return false
        }

        start()
        return true
    }

    /// Reconciles future silent prompts, clearing them during capture or when disabled.
    func updateCalendarPrompts(at date: Date = .now) async {
        do {
            try await notifier?.updateMeetingPrompts(
                isEnabled && calendarPromptsEnabled && phase == .idle ? calendarMeetings.filter(\.canPrompt) : [],
                at: date,
            )
        } catch {
            notificationMessage = "Could not update calendar reminders: \(error.localizedDescription)"
        }
    }

    internal func applyCalendarTitle() {
        if myName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let name = calendarMeeting?.myName
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            myName = ParticipantNames.displayName(name)
        }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title == suggestedTitle {
            title = calendarMeeting?.title ?? ""
        }
        suggestedTitle = calendarMeeting?.title
    }
}
