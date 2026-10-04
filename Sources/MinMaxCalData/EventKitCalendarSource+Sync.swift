import EventKit
import Foundation
import MinMaxCalDomain

public extension EventKitCalendarSource {
    /// Fetches the window and known copies moved outside it.
    func syncSnapshot(
        policies: [SyncPolicy], links: [SyncLink], interval: DateInterval,
    ) throws -> (calendars: [CalendarList], events: [SyncEvent]) {
        guard accessStatus().events == .full else {
            throw SyncError.access
        }

        let identifiers = Set(policies.flatMap { [$0.source, $0.destination] }
            + links.flatMap { [$0.source.calendar, $0.destination] })
        let calendars = store.calendars(for: .event).filter { identifiers.contains($0.calendarIdentifier) }
        guard calendars.isEmpty == false else {
            return ([], [])
        }

        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        var events = store.events(matching: predicate).map(EventKitDecoder.syncEvent)
        for identity in links.compactMap(\.copy) {
            guard let event = store.event(withIdentifier: identity.event),
                  identity.matches(EventKitDecoder.syncEvent(event).identity),
                  events.contains(where: { identity.matches($0.identity) }) == false
            else {
                continue
            }

            events.append(EventKitDecoder.syncEvent(event))
        }
        return (calendars.map { EventKitDecoder.list($0, kind: .event) }, events)
    }

    /// Revalidates content and ownership before each mutation.
    func applySync(_ write: SyncWrite) throws -> SyncIdentity? {
        let event = try validatedEvent(for: write)
        switch write {
        case let .save(_, _, _, content):
            EventKitDecoder.apply(content, to: event)
            if event.hasChanges {
                try store.save(event, span: .thisEvent, commit: true)
            }
            return EventKitDecoder.syncEvent(event).identity

        case .remove:
            try store.remove(event, span: .thisEvent, commit: true)
            return nil
        }
    }

    /// Checks the live prerequisites and prepares fields without changing a stored event.
    func rehearseSync(_ write: SyncWrite) throws {
        let event = try validatedEvent(for: write)
        if case let .save(_, _, _, content) = write {
            let draft = EKEvent(eventStore: store)
            draft.calendar = event.calendar
            EventKitDecoder.apply(content, to: draft)
        }
    }

    /// Removes a reviewed legacy copy within the window.
    func removeLegacyCopy(_ event: SyncEvent, interval: DateInterval) throws {
        guard accessStatus().events == .full else {
            throw SyncError.access
        }
        guard event.content.start < interval.end, event.content.end > interval.start,
              event.hasAttendees == false, SyncMarker.isLegacy(event.content.notes)
        else {
            throw SyncError.ownership
        }

        let current = try current(event)
        guard current.calendar.allowsContentModifications else {
            throw SyncError.calendar
        }

        try store.remove(current, span: .thisEvent, commit: true)
    }

    private func validatedEvent(for write: SyncWrite) throws -> EKEvent {
        guard accessStatus().events == .full else {
            throw SyncError.access
        }

        switch write {
        case let .save(link, source, target, content):
            _ = try current(source)
            guard let calendar = store.calendar(withIdentifier: link.destination),
                  calendar.allowsContentModifications, calendar.supportedEventAvailabilities.contains(.busy)
            else {
                throw SyncError.calendar
            }

            let event: EKEvent
            if let target {
                event = try current(target)
                try verifyOwnership(target, link: link)
            } else {
                let predicate = store.predicateForEvents(
                    withStart: content.start, end: content.end, calendars: [calendar],
                )
                guard store.events(matching: predicate).contains(where: { event in
                    EventKitDecoder.syncEvent(event).preventsCreation(for: link, source: source)
                }) == false else {
                    throw SyncError.changed
                }

                event = EKEvent(eventStore: store)
                event.calendar = calendar
            }
            return event

        case let .remove(link, target, _):
            let event = try current(target)
            try verifyOwnership(target, link: link)
            guard event.calendar.allowsContentModifications else {
                throw SyncError.calendar
            }

            return event
        }
    }

    private func current(_ expected: SyncEvent) throws -> EKEvent {
        guard let calendar = store.calendar(withIdentifier: expected.identity.calendar)
        else {
            throw SyncError.calendar
        }

        let predicate = store.predicateForEvents(
            withStart: expected.content.start, end: expected.content.end, calendars: [calendar],
        )
        let matches = store.events(matching: predicate).filter { event in
            expected.identity.matches(EventKitDecoder.syncEvent(event).identity)
        }
        guard matches.count == 1, let event = matches.first, EventKitDecoder.syncEvent(event) == expected else {
            throw SyncError.changed
        }

        return event
    }

    private func verifyOwnership(_ event: SyncEvent, link: SyncLink) throws {
        guard event.isOwned(by: link) else {
            throw SyncError.ownership
        }
    }
}
