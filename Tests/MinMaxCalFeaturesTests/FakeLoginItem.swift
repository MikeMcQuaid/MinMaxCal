import MinMaxCalData
import Synchronization

nonisolated final class FakeLoginItem: LoginItem {
    // MARK: Internal

    var status: LoginItemStatus {
        state.withLock(\.status)
    }

    var isInstalledCopy: Bool {
        get { state.withLock(\.isInstalledCopy) }
        set { state.withLock { $0.isInstalledCopy = newValue } }
    }

    func register() {
        state.withLock { $0.status = .enabled }
    }

    func unregister() {
        state.withLock { $0.status = .notRegistered }
    }

    func openSystemSettings() {
        // System Settings cannot open from a test.
    }

    // MARK: Private

    private struct State {
        var status: LoginItemStatus = .notRegistered
        var isInstalledCopy = true
    }

    private let state: Mutex = .init(State())
}
