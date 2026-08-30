import AppKit
import Foundation
import MinMaxCalDomain

public struct WorkspaceLinkOpener: LinkOpener {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func open(_ link: JoinLink, in bundleIdentifier: String?) {
        let workspace = NSWorkspace.shared
        guard let bundleIdentifier,
              let application = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            open(link.url)
            return
        }

        let url = bundleIdentifier == link.service.app?.bundleIdentifier ? link.appURL ?? link.url : link.url
        workspace.open([url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// The service's own app when it is installed, then the handlers of a web address, each app
    /// once by name order.
    public func apps(for service: JoinLink.Service) -> [JoinApp] {
        let workspace = NSWorkspace.shared
        let own = [service.app]
            .compactMap(\.self)
            .filter { workspace.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil }
        var identifiers = Set(own.map(\.bundleIdentifier))
        guard let probe = Self.webProbe else {
            return own
        }

        return own + workspace
            .urlsForApplications(toOpen: probe)
            .compactMap { url in
                guard let identifier = Bundle(url: url)?.bundleIdentifier else {
                    return nil as JoinApp?
                }

                return JoinApp(
                    bundleIdentifier: identifier,
                    name: FileManager.default.displayName(atPath: url.path),
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .filter { identifiers.insert($0.bundleIdentifier).inserted }
    }

    // MARK: Private

    private static let webProbe: URL? = URL(string: "https://example.com")
}
