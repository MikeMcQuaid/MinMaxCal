import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Synchronization

nonisolated final class FakeCalendarSyncSource: CalendarSyncSource {
    // MARK: Lifecycle

    init(
        events: [SyncEvent],
        calendars: [CalendarList],
        beforeSnapshot: @escaping @Sendable () async -> Void = {},
    ) {
        state = Mutex(State(events: events, calendars: calendars))
        self.beforeSnapshot = beforeSnapshot
    }

    // MARK: Internal

    var writes: Int {
        state.withLock(\.writes)
    }

    var fetches: Int {
        state.withLock(\.fetches)
    }

    var rehearsals: Int {
        state.withLock { $0.rehearsedActions.count }
    }

    var rehearsedActions: [SyncWrite.Action] {
        state.withLock(\.rehearsedActions)
    }

    var rehearsalError: SyncError? {
        get { state.withLock(\.rehearsalError) }
        set { state.withLock { $0.rehearsalError = newValue } }
    }

    var failAfterSave: Bool {
        get { state.withLock(\.failAfterSave) }
        set { state.withLock { $0.failAfterSave = newValue } }
    }

    func rehearseSync(_ write: SyncWrite) throws {
        try state.withLock { state in
            state.rehearsedActions.append(write.action)
            if let error = state.rehearsalError {
                throw error
            }
        }
    }

    func syncSnapshot(
        policies _: [SyncPolicy], links _: [SyncLink], interval _: DateInterval,
    ) async -> (calendars: [CalendarList], events: [SyncEvent]) {
        await beforeSnapshot()
        return state.withLock { state in
            state.fetches += 1
            return (state.calendars, state.events)
        }
    }

    func applySync(_ write: SyncWrite) throws -> SyncIdentity? {
        try state.withLock { state in
            state.writes += 1
            switch write {
            case let .save(link, _, target, content):
                let identity = target?.identity
                    ?? SyncIdentity(calendar: link.destination, item: link.id.uuidString, event: link.id.uuidString)
                state.events.removeAll { $0.identity == identity }
                state.events.append(SyncEvent(identity: identity, content: content))
                if state.failAfterSave {
                    throw CocoaError(.fileWriteUnknown)
                }
                return identity

            case let .remove(_, target, _):
                state.events.removeAll { $0.identity == target.identity }
                return nil
            }
        }
    }

    func removeLegacyCopy(_ event: SyncEvent, interval _: DateInterval) {
        state.withLock { state in
            state.writes += 1
            state.events.removeAll { $0.identity == event.identity }
        }
    }

    // MARK: Private

    private struct State {
        var events: [SyncEvent]
        var calendars: [CalendarList]
        var writes = 0
        var fetches = 0
        var failAfterSave = false
        var rehearsedActions: [SyncWrite.Action] = []
        var rehearsalError: SyncError?
    }

    private let state: Mutex<State>
    private let beforeSnapshot: @Sendable () async -> Void
}
