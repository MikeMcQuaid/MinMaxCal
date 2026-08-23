import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Synchronization

nonisolated final class FakeCalendarSource: CalendarSource {
    // MARK: Internal

    let changes = AsyncStream<Void> { $0.finish() }

    var items: [AgendaItem] {
        get { state.withLock(\.items) }
        set { state.withLock { $0.items = newValue } }
    }

    var availableLists: [CalendarList] {
        get { state.withLock(\.availableLists) }
        set { state.withLock { $0.availableLists = newValue } }
    }

    var completed: [MemberIdentity] {
        state.withLock(\.completed)
    }

    var completionError: FakeError? {
        get { state.withLock(\.completionError) }
        set { state.withLock { $0.completionError = newValue } }
    }

    func requestAccess() -> AccessStatus {
        state.withLock(\.access)
    }

    func accessStatus() -> AccessStatus {
        state.withLock(\.access)
    }

    func lists() -> [CalendarList] {
        availableLists
    }

    func agenda(from _: Date, to _: Date, selection: Selection, rules _: MatchingRules) -> [AgendaItem] {
        selection.isEmpty ? [] : items
    }

    func complete(reminder: MemberIdentity) throws {
        try state.withLock { state in
            if let error = state.completionError {
                throw error
            }
            state.completed.append(reminder)
        }
    }

    // MARK: Private

    private struct State {
        var items: [AgendaItem] = []
        var availableLists: [CalendarList] = []
        var completed: [MemberIdentity] = []
        var completionError: FakeError?
        var access: AccessStatus = .init(events: .full, reminders: .full)
    }

    private let state: Mutex = .init(State())
}
