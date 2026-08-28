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

    var fetches: Int {
        state.withLock(\.fetches)
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
        state.withLock { state in
            state.fetches += 1
            return selection.isEmpty ? [] : state.items
        }
    }

    func setCompleted(_ completed: Bool, reminder: MemberIdentity) throws {
        try state.withLock { state in
            if let error = state.completionError {
                throw error
            }
            if completed {
                state.completed.append(reminder)
            } else {
                state.completed.removeAll { $0 == reminder }
            }
        }
    }

    // MARK: Private

    private struct State {
        var items: [AgendaItem] = []
        var availableLists: [CalendarList] = []
        var completed: [MemberIdentity] = []
        var fetches = 0
        var completionError: FakeError?
        var access: AccessStatus = .init(events: .full, reminders: .full)
    }

    private let state: Mutex = .init(State())
}
