import MinMaxCalData
import MinMaxCalFeatures
import SwiftUI

@main
struct MinMaxCalApp: App {
    // MARK: Lifecycle

    init() {
        let source = EventKitCalendarSource()
        let store = SettingsStore()
        let opener = WorkspaceLinkOpener()
        let windows = TakeoverWindowController { AnyView(EmptyView()) }
        let takeover = TakeoverModel(
            source: source,
            opener: opener,
            ledger: TakeoverLedgerStore(),
            settings: store,
            presenter: windows,
        )
        windows.content = { AnyView(TakeoverView(model: takeover)) }
        agenda = AgendaModel(source: source, settings: store, opener: opener, wake: WakeNotifications.stream)
        agenda.onRebuild = takeover.schedule
        takeover.onAction = agenda.requestRefresh
        settings = SettingsModel(source: source, store: store, loginItem: SMAppServiceLoginItem())
        settings.preview = takeover.preview
        settings.registerLoginItemOnFirstInstalledLaunch()
    }

    // MARK: Internal

    var body: some Scene {
        MenuBarExtra {
            AgendaView(model: agenda)
        } label: {
            MenuBarLabel(model: agenda)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: settings)
        }
    }

    // MARK: Private

    private let agenda: AgendaModel
    private let settings: SettingsModel
}
