import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Synchronization

nonisolated final class FakeLinkOpener: LinkOpener {
    // MARK: Internal

    var opened: [JoinLink] {
        links.withLock { $0 }
    }

    func open(_ link: JoinLink) {
        links.withLock { $0.append(link) }
    }

    func open(_: URL) {
        // Plain URLs are only opened by the General tab, which is not tested here.
    }

    // MARK: Private

    private let links: Mutex<[JoinLink]> = .init([])
}
