import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Observation
import SwiftUI

/// Backs the Settings window: selection, rules, takeover switches, login item and permissions.
@Observable
public final class SettingsModel {
    // MARK: Lifecycle

    /// Wires the ports and reads the stored settings.
    public init(source: any CalendarSource, store: SettingsStore, loginItem: any LoginItem) {
        self.source = source
        self.store = store
        self.loginItem = loginItem
        selection = store.selection
        rules = store.matchingRules
        takeover = store.takeover
        titleLimit = store.titleLimit
    }

    // MARK: Public

    /// Every calendar and reminder list on the Mac.
    public private(set) var lists: [CalendarList] = []
    /// The Calendars and Reminders grants the app holds.
    public private(set) var access: AccessStatus = .notDetermined
    /// What launchd says about the login item.
    public private(set) var loginItemStatus: LoginItemStatus = .notRegistered
    /// Why the last login item change failed.
    public private(set) var errorMessage: String?
    /// Shows a sample takeover; the app points this at `TakeoverModel.preview`.
    public var preview: (AgendaItem.Sample) -> Void = { _ in }

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
        AccountGroup.grouping(lists, of: .event)
    }

    /// The reminder lists grouped by account.
    public var reminderGroups: [AccountGroup] {
        AccountGroup.grouping(lists, of: .reminder)
    }

    /// Refreshes the lists, permissions and login item status.
    public func load() async {
        lists = await source.lists()
        access = source.accessStatus()
        loginItemStatus = loginItem.status
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
}
