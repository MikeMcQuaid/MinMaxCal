import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Synchronization

nonisolated final class FakeLinkOpener: LinkOpener {
    // MARK: Internal

    var opened: [JoinLink] {
        calls.withLock { $0.map(\.link) }
    }

    /// The bundle identifier each link was asked to open in.
    var openedIn: [String?] {
        calls.withLock { $0.map(\.app) }
    }

    /// What `apps(for:)` reports installed, whatever the service.
    var installed: [JoinApp] {
        get { installedApps.withLock { $0 } }
        set { installedApps.withLock { $0 = newValue } }
    }

    func open(_ link: JoinLink, in bundleIdentifier: String?) {
        calls.withLock { $0.append((link, bundleIdentifier)) }
    }

    func open(_: URL) {
        // Plain URLs are only opened by the General tab, which is not tested here.
    }

    func apps(for _: JoinLink.Service) -> [JoinApp] {
        installed
    }

    // MARK: Private

    private let calls: Mutex<[(link: JoinLink, app: String?)]> = .init([])
    private let installedApps: Mutex<[JoinApp]> = .init([])
}
