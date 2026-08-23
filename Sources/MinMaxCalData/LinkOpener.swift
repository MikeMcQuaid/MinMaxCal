import Foundation
import MinMaxCalDomain

public protocol LinkOpener: Sendable {
    func open(_ link: JoinLink)
    func open(_ url: URL)
}
