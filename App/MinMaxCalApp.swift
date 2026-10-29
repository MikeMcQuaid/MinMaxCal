import AppIntents
import MinMaxCalAgenda
import MinMaxCalCoachingFeatures
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
            powerChanges: PowerState.changes,
        )
        let sync = CalendarSyncModel(source: source, settings: store)
        agendaModel.syncLinks = { sync.links }
        sync.onMappingChange = agendaModel.requestRefresh
        agendaModel.preview = takeover.preview
        takeover.onAction = agendaModel.requestRefresh
        // Register dependencies on the main actor before any intent can run.
        unsafe AppDependencyManager.shared.add(dependency: agendaModel)
        unsafe AppDependencyManager.shared.add(dependency: takeover)
        let settingsModel = SettingsModel(
            source: source,
            store: store,
            loginItem: SMAppServiceLoginItem(),
            opener: opener,
        )
        settingsModel.sync = sync
        #if APP_STORE
        settingsModel.registerLoginItemOnFirstInstalledLaunch(automatically: false)
        #else
        settingsModel.registerLoginItemOnFirstInstalledLaunch()
        #endif
        agenda = agendaModel
        settings = settingsModel
        coaching = makeCoaching(agenda: agendaModel, takeover: takeover, sync: sync)
        // The loop lives as long as the app: nothing in a menu bar app
        // owns a view that is reliably alive to host it as a `.task`.
        Task {
            await agendaModel.run()
        }
    }

    // MARK: Internal

    static let includedPackages: [any AppIntentsPackage.Type] = [MinMaxCalIntents.self]

    @NSApplicationDelegateAdaptor(CoachingAppDelegate.self)
    var delegate

    var body: some Scene {
        MenuBarExtra {
            AgendaView(model: agenda, coaching: coaching)
        } label: {
            MenuBarLabel(model: agenda, recordingSymbol: coaching?.symbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: settings, coaching: coaching)
        }
    }

    // MARK: Private

    private var coaching: CoachingController?
    private let agenda: AgendaModel
    private let settings: SettingsModel
}
