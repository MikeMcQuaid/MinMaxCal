import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Observation
import SwiftUI

/// Backs the Settings window: selection, rules, takeover switches, join apps, login item and
/// permissions.
@Observable
public final class SettingsModel {
    // MARK: Lifecycle

    /// Wires the ports and reads the stored settings.
    public init(source: any CalendarSource, store: SettingsStore, loginItem: any LoginItem, opener: any LinkOpener) {
        self.source = source
        self.store = store
        self.loginItem = loginItem
        self.opener = opener
        selection = store.selection
        rules = store.matchingRules
        takeover = store.takeover
        join = store.join
        titleLimit = store.titleLimit
    }

    // MARK: Public

    /// Every calendar and reminder list on the Mac.
    public private(set) var lists: [CalendarList] = []
    /// The Calendars and Reminders grants the app holds.
    public private(set) var access: AccessStatus = .notDetermined
    /// What launchd says about the login item.
    public private(set) var loginItemStatus: LoginItemStatus = .notRegistered
    /// The sounds a takeover can arrive with, from the Sounds folders.
    public private(set) var sounds: [TakeoverSound] = []
    /// The installed apps that open each service's links.
    public private(set) var installedApps: [JoinLink.Service: [JoinApp]] = [:]
    /// Why the last login item change failed.
    public private(set) var errorMessage: String?

    /// The selected calendars and lists, written through to the store.
    public var selection: Selection {
        didSet { store.selection = selection }
    }

    /// The matching rules, written through to the store.
    public var rules: MatchingRules {
        didSet { store.matchingRules = rules }
    }

    /// The takeover switches and snooze durations, written through to the store.
    public var takeover: TakeoverSettings {
        didSet { store.takeover = takeover }
    }

    /// The app each call service opens in, written through to the store.
    public var join: JoinSettings {
        didSet { store.join = join }
    }

    /// The menu bar title length, written through to the store.
    public var titleLimit: Int {
        didSet { store.titleLimit = titleLimit }
    }

    /// Whether the login item is registered; setting it registers or unregisters.
    public var launchAtLogin: Bool {
        get { loginItemStatus == .enabled || loginItemStatus == .requiresApproval }
        set {
            do {
                if newValue {
                    try loginItem.register()
                } else {
                    try loginItem.unregister()
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            loginItemStatus = loginItem.status
        }
    }

    /// The calendars grouped by account.
    public var calendarGroups: [AccountGroup] {
        AccountGroup.grouping(lists.filter { $0.kind == .event })
    }

    /// The reminder lists grouped by account.
    public var reminderGroups: [AccountGroup] {
        AccountGroup.grouping(lists.filter { $0.kind == .reminder })
    }

    /// Refreshes the lists, sounds, apps, permissions and login item status.
    public func load() async {
        lists = await source.lists()
        sounds = TakeoverSound.installed
        for service in JoinLink.Service.allCases {
            installedApps[service] = opener.apps(for: service)
        }
        access = source.accessStatus()
        loginItemStatus = loginItem.status
    }

    /// The apps to offer for `service`: those installed, and the chosen one when it is no longer
    /// installed, so the picker never goes blank.
    public func joinApps(for service: JoinLink.Service) -> [JoinApp] {
        let installed = installedApps[service] ?? []
        guard let chosen = join[service], installed.contains(where: { $0.bundleIdentifier == chosen }) == false else {
            return installed
        }

        let known = [JoinApp.zoom, JoinApp.edge].first { $0.bundleIdentifier == chosen }
        return installed + [JoinApp(bundleIdentifier: chosen, name: "\(known?.name ?? chosen) (not installed)")]
    }

    /// A binding for one service's app picker.
    public func app(for service: JoinLink.Service) -> Binding<String?> {
        Binding(
            get: { self.join[service] },
            set: { self.join[service] = $0 },
        )
    }

    /// Registers the login item once, and only for the copy in /Applications.
    public func registerLoginItemOnFirstInstalledLaunch() {
        guard loginItem.isInstalledCopy, store.hasRegisteredLoginItem == false else {
            return
        }

        try? loginItem.register()
        store.hasRegisteredLoginItem = true
        loginItemStatus = loginItem.status
    }

    /// Opens the Login Items pane for the user to approve the item.
    public func openLoginItemsSettings() {
        loginItem.openSystemSettings()
    }

    /// A binding for one list's checkbox.
    public func isSelected(_ list: CalendarList) -> Binding<Bool> {
        Binding(
            get: { self.selection.contains(list) },
            set: { self.selection.set(list, selected: $0) },
        )
    }

    // MARK: Private

    @ObservationIgnored private let source: any CalendarSource
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let loginItem: any LoginItem
    @ObservationIgnored private let opener: any LinkOpener
}
