import AppKit
import EventKit
import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Testing

struct EventKitDecoderTests {
    // MARK: Internal

    @Test
    func `decodes an event with its join link`() {
        let event = EKEvent(eventStore: store)
        event.calendar = calendar("Work", for: .event)
        event.title = "Weekly planning"
        event.startDate = Date(timeIntervalSinceReferenceDate: 800_000_040)
        event.endDate = event.startDate.addingTimeInterval(1_800)
        event.location = "Boardroom"
        event.notes = "Join https://zoom.us/j/123?pwd=abc"
        event.url = URL(string: "https://example.com/agenda")

        let item = EventKitDecoder.item(event, rules: rules)

        #expect(item.kind == .event)
        #expect(item.title == "Weekly planning")
        #expect(item.start == event.startDate)
        #expect(item.end == event.endDate)
        let member = MemberIdentity(
            calendarItemIdentifier: event.calendarItemIdentifier,
            occurrenceDate: event.startDate,
        )
        #expect(item.members == [member])
        #expect(item.calendars.map(\.title) == ["Work"])
        #expect(item.location == "Boardroom")
        #expect(item.url == event.url)
        #expect(item.joinLink?.service == .zoom)
        #expect(item.attendees.isEmpty)
        #expect(item.isAccepted)
        #expect(item.isCancelled == false)
    }

    @Test
    func `decodes all day events`() {
        let event = EKEvent(eventStore: store)
        event.calendar = calendar("Home", for: .event)
        event.title = "Offsite"
        event.isAllDay = true
        event.startDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        event.endDate = event.startDate.addingTimeInterval(86_400)

        #expect(EventKitDecoder.item(event, rules: rules).isAllDay)
    }

    @Test
    func `decodes timed and date only reminders`() throws {
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar("Errands", for: .reminder)
        reminder.title = "Buy milk"
        reminder.dueDateComponents = DateComponents(
            calendar: .current,
            year: 2_026,
            month: 8,
            day: 23,
            hour: 17,
            minute: 30,
        )

        let timed = try #require(EventKitDecoder.item(reminder, rules: rules))
        #expect(timed.kind == .reminder)
        #expect(timed.title == "Buy milk")
        #expect(timed.isAllDay == false)
        #expect(timed.end == nil)
        #expect(timed.start == Calendar.current.date(from: DateComponents(
            year: 2_026,
            month: 8,
            day: 23,
            hour: 17,
            minute: 30,
        )))
        #expect(timed.calendars.map(\.kind) == [.reminder])

        reminder.dueDateComponents = DateComponents(calendar: .current, year: 2_026, month: 8, day: 23)
        let dateOnly = try #require(EventKitDecoder.item(reminder, rules: rules))
        #expect(dateOnly.isAllDay)

        reminder.dueDateComponents = nil
        #expect(EventKitDecoder.item(reminder, rules: rules) == nil)
    }

    @Test
    func `decodes calendar colours`() {
        let list = calendar("Colourful", for: .event)
        list.color = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.6, alpha: 1)

        let decoded = EventKitDecoder.list(list, kind: .event)

        #expect(abs(decoded.colour.red - 0.2) < 0.01)
        #expect(abs(decoded.colour.green - 0.4) < 0.01)
        #expect(abs(decoded.colour.blue - 0.6) < 0.01)
        #expect(decoded.kind == .event)
    }

    // MARK: Private

    private let store: EKEventStore = .init()
    private let rules: MatchingRules = .default

    private func calendar(_ title: String, for kind: EKEntityType) -> EKCalendar {
        let calendar = EKCalendar(for: kind, eventStore: store)
        calendar.title = title
        return calendar
    }
}
