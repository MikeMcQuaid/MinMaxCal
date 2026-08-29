import Foundation
import MinMaxCalDomain

public protocol LinkOpener: Sendable {
    /// Opens a call link in the app with `bundleIdentifier`, or the default browser when that is
    /// nil or the app is missing.
    func open(_ link: JoinLink, in bundleIdentifier: String?)
    func open(_ url: URL)
    /// The installed apps that can open `service`'s links.
    func apps(for service: JoinLink.Service) -> [JoinApp]
}
