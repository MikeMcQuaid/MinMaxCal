import Foundation
import ServiceManagement

public struct SMAppServiceLoginItem: LoginItem {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public static let installedPath = "/Applications/MinMaxCal.app"

    public var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            .enabled

        case .requiresApproval:
            .requiresApproval

        case .notFound:
            .notFound

        case .notRegistered:
            .notRegistered

        @unknown default:
            .notRegistered
        }
    }

    public var isInstalledCopy: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path() == Self.installedPath
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
