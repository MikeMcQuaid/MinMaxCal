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

        let url = bundleIdentifier == JoinApp.zoom.bundleIdentifier ? link.zoomURL ?? link.url : link.url
        workspace.open([url], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
    }

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// The handlers of a web address and, for Zoom, of `zoommtg://` first, each app once by name order.
    public func apps(for service: JoinLink.Service) -> [JoinApp] {
        let probes = service == .zoom ? [Self.zoomProbe, Self.webProbe] : [Self.webProbe]
        var identifiers = Set<String>()
        return probes.compactMap(\.self).flatMap { probe in
            NSWorkspace.shared
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
    }

    // MARK: Private

    private static let zoomProbe: URL? = URL(string: "zoommtg://zoom.us/join")
    private static let webProbe: URL? = URL(string: "https://example.com")
}
