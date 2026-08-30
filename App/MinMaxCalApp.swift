import AppIntents
import MinMaxCalData
import MinMaxCalDomain
import MinMaxCalFeatures
import MinMaxCalIntents
import SwiftUI

@main
struct MinMaxCalApp: App, AppIntentsPackage {
    // MARK: Lifecycle

    init() {
        let source = EventKitCalendarSource()
        let opener = WorkspaceLinkOpener()
        let store =
            SettingsStore(defaultJoin: .default(teamsInstalled: opener.apps(for: .teams).contains(JoinApp.teams)))
        let windows = TakeoverWindowController { AnyView(EmptyView()) }
        let takeover = TakeoverModel(
            source: source,
            opener: opener,
            ledger: TakeoverLedgerStore(),
            settings: store,
            presenter: windows,
        )
        windows.content = { AnyView(TakeoverView(model: takeover)) }
        let agendaModel = AgendaModel(
            source: source,
            settings: store,
            opener: opener,
            systemChanges: SystemChanges.stream,
        )
        agendaModel.onRebuild = takeover.schedule
        agendaModel.preview = takeover.preview
        takeover.onAction = agendaModel.requestRefresh
        AppDependencyManager.shared.add(dependency: agendaModel)
        AppDependencyManager.shared.add(dependency: takeover)
        let settingsModel = SettingsModel(
            source: source,
            store: store,
            loginItem: SMAppServiceLoginItem(),
            opener: opener,
        )
        settingsModel.registerLoginItemOnFirstInstalledLaunch()
        // The loop lives as long as the app: nothing in a menu bar app
        // owns a view that is reliably alive to host it as a `.task`.
        Task { await agendaModel.run() }
        agenda = agendaModel
        settings = settingsModel
    }

    // MARK: Internal

    static let includedPackages: [any AppIntentsPackage.Type] = [MinMaxCalIntents.self]

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
