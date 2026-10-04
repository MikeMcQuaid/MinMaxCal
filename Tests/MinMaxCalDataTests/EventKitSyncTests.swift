import EventKit
import Foundation
@testable import MinMaxCalData
import MinMaxCalDomain
import Testing

struct EventKitSyncTests {
    @Test
    func `a mirror has plain ownership notes no alarms and cannot take over alone`() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.alarms = [EKAlarm(relativeOffset: -300)]
        let content = SyncContent(
            title: "Busy",
            start: Date(timeIntervalSinceReferenceDate: 800_000_000),
            end: Date(timeIntervalSinceReferenceDate: 800_003_600),
            timeZone: "Europe/London",
            notes: SyncMarker.footer(UUID()),
        )
        EventKitDecoder.apply(content, to: event)
        #expect(event.alarms?.isEmpty == true)
        #expect(event.hasAttendees == false)
        #expect(event.hasRecurrenceRules == false)
        var expected = content
        // An unsaved calendar cannot support availability without an account.
        expected.availability = .unknown
        #expect(EventKitDecoder.syncEvent(event).content == expected)
        #expect(EventKitDecoder.syncEvent(event).identity.occurrence == nil)
        #expect(EventKitDecoder.item(event).isAccepted == false)
    }

    @Test
    func `recurring originals retain an occurrence identity`() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = EKCalendar(for: .event, eventStore: store)
        event.title = "Standup"
        event.startDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        event.endDate = event.startDate.addingTimeInterval(1_800)
        event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil))
        #expect(EventKitDecoder.syncEvent(event).identity.occurrence == event.occurrenceDate)
        #expect(EventKitDecoder.item(event).recurrenceDate == event.occurrenceDate)
    }
}
