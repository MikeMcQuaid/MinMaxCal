import Foundation
import MinMaxCalDomain

enum SyncFixtures {
    static let legacy = """
    This event was created by <a href="https://app.reclaim.ai/signup?utm_medium=calendar-sync-event">Calendar Sync</a>.
    """
    static let policy: SyncPolicy = .init(source: "home", destination: "work", isEnabled: true)
    static let legacyFirstUID = "e9im6r31d5miqs35e9pmurj1dgmn6ubecct5upb4dpn62sra6dhmmrbdelp6kd8@google.com"
    static let legacySecondUID = "e9im6r31d5miqs35e9pmurj1dgmn6ubecct5upb4dpn62sra6dhmmrbe71q74pg@google.com"

    static var interval: DateInterval {
        DateInterval(start: Fixtures.now, duration: 86_400)
    }

    static var calendars: [CalendarList] {
        [Fixtures.home, Fixtures.work].map { calendar in
            var writable = calendar
            writable.allowsChanges = true
            writable.supportsBusy = true
            return writable
        }
    }

    static var original: SyncEvent {
        SyncEvent(
            identity: SyncIdentity(calendar: "home", item: "source", event: "source"),
            content: SyncContent(
                title: "Appointment",
                start: Fixtures.now.addingTimeInterval(600),
                end: Fixtures.now.addingTimeInterval(1_800),
                location: "Clinic",
                notes: "Secret. https://meet.google.com/abc-defg-hij",
            ),
        )
    }

    static func plan(events: [SyncEvent], policies: [SyncPolicy] = [], links: [SyncLink] = []) -> SyncPlan {
        SyncPlanner(
            events: events,
            calendars: calendars,
            policies: policies.isEmpty ? [policy] : policies,
            links: links,
            interval: interval,
        ).plan()
    }
}
