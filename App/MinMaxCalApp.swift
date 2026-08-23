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
        let agendaModel = AgendaModel(source: source, settings: store, opener: opener, wake: WakeNotifications.stream)
        agendaModel.onRebuild = takeover.schedule
        agendaModel.preview = takeover.preview
        takeover.onAction = agendaModel.requestRefresh
        let settingsModel = SettingsModel(source: source, store: store, loginItem: SMAppServiceLoginItem())
        settingsModel.registerLoginItemOnFirstInstalledLaunch()
        // The loop lives as long as the app: nothing in a menu bar app
        // owns a view that is reliably alive to host it as a `.task`.
        Task { await agendaModel.run() }
        agenda = agendaModel
        settings = settingsModel
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
