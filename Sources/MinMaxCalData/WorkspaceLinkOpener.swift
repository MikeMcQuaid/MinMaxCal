import AppKit
import Foundation
import MinMaxCalDomain

public struct WorkspaceLinkOpener: LinkOpener {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func open(_ link: JoinLink) {
        let workspace = NSWorkspace.shared
        guard let bundleIdentifier = link.app.bundleIdentifier,
              let application = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            open(link.url)
            return
        }

        workspace.open([link.url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
