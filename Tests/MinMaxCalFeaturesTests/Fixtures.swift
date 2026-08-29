import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Testing

nonisolated enum Fixtures {
    static let now: Date = .init(timeIntervalSinceReferenceDate: 800_000_040)
    static let clock: @Sendable () -> Date = { now }
    static let work: CalendarList = .init(
        identifier: "work",
        title: "Work",
        colour: ListColour(red: 0.2, green: 0.4, blue: 0.9),
        kind: .event,
        accountName: "Work",
    )
    static let list: CalendarList = .init(
        identifier: "list",
        title: "Reminders",
        colour: .grey,
        kind: .reminder,
        accountName: "iCloud",
    )
    static let selection: Selection = .init(
        calendarIdentifiers: [work.identifier],
        reminderListIdentifiers: [list.identifier],
    )

    static func event(
        _ identifier: String,
        title: String = "Event",
        startingIn minutes: Double = 30,
        link: JoinLink? = nil,
    ) -> AgendaItem {
        let start = now.addingTimeInterval(minutes * 60)
        return AgendaItem(
            members: [MemberIdentity(calendarItemIdentifier: identifier, occurrenceDate: start)],
            kind: .event,
            title: title,
            start: start,
            end: start.addingTimeInterval(30 * 60),
            calendars: [work],
            joinLink: link,
        )
    }

    static func reminder(_ identifier: String, title: String = "Reminder", dueIn minutes: Double = 30) -> AgendaItem {
        AgendaItem(
            members: [MemberIdentity(calendarItemIdentifier: identifier)],
            kind: .reminder,
            title: title,
            start: now.addingTimeInterval(minutes * 60),
            calendars: [list],
        )
    }

    @MainActor
    static func settingsStore() throws -> SettingsStore {
        let suite = "MinMaxCalFeaturesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        store.selection = selection
        return store
    }

    static func ledgerStore() -> TakeoverLedgerStore {
        TakeoverLedgerStore(file: scratchDirectory().appending(path: "takeovers.json"))
    }

    static func scratchDirectory(_ file: String = #filePath) -> URL {
        let checkout = URL(filePath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = checkout.appending(path: ".test-scratch").appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
