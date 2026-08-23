import EventKit
import Foundation
import MinMaxCalDomain

public actor EventKitCalendarSource: CalendarSource {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    nonisolated public var changes: AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func requestAccess() async -> AccessStatus {
        _ = try? await store.requestFullAccessToEvents()
        _ = try? await store.requestFullAccessToReminders()
        return accessStatus()
    }

    nonisolated public func accessStatus() -> AccessStatus {
        AccessStatus(
            events: Self.grant(EKEventStore.authorizationStatus(for: .event)),
            reminders: Self.grant(EKEventStore.authorizationStatus(for: .reminder)),
        )
    }

    public func lists() -> [CalendarList] {
        store.calendars(for: .event).map { EventKitDecoder.list($0, kind: .event) }
            + store.calendars(for: .reminder).map { EventKitDecoder.list($0, kind: .reminder) }
    }

    public func agenda(
        from start: Date,
        to end: Date,
        selection: Selection,
        rules: MatchingRules,
    ) async -> [AgendaItem] {
        await events(from: start, to: end, selection: selection, rules: rules)
            + reminders(until: end, selection: selection, rules: rules)
    }

    public func setCompleted(_ completed: Bool, reminder member: MemberIdentity) throws {
        guard let reminder = store.calendarItem(withIdentifier: member.calendarItemIdentifier) as? EKReminder else {
            throw CalendarSourceError.reminderNotFound
        }

        reminder.isCompleted = completed
        try store.save(reminder, commit: true)
    }

    // MARK: Private

    private let store: EKEventStore = .init()

    private static func grant(_ status: EKAuthorizationStatus) -> AccessStatus.Grant {
        switch status {
        case .authorized,
             .fullAccess:
            .full

        case .denied:
            .denied

        case .restricted:
            .restricted

        case .writeOnly:
            .writeOnly

        case .notDetermined:
            .notDetermined

        @unknown default:
            .notDetermined
        }
    }

    private func events(from start: Date, to end: Date, selection: Selection, rules: MatchingRules) -> [AgendaItem] {
        let calendars = store.calendars(for: .event)
            .filter { selection.calendarIdentifiers.contains($0.calendarIdentifier) }
        guard calendars.isEmpty == false else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).map { EventKitDecoder.item($0, rules: rules) }
    }

    private func reminders(until end: Date, selection: Selection, rules: MatchingRules) async -> [AgendaItem] {
        let lists = store.calendars(for: .reminder)
            .filter { selection.reminderListIdentifiers.contains($0.calendarIdentifier) }
        guard lists.isEmpty == false else {
            return []
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: .distantPast,
            ending: end,
            calendars: lists,
        )
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).compactMap { EventKitDecoder.item($0, rules: rules) })
            }
        }
    }
}
