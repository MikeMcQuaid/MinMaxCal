import MinMaxCalAgenda
import MinMaxCalData
import SwiftUI
import UIKit

@main
struct MinMaxCalApp: App {
    // MARK: Lifecycle

    init() {
        source = EventKitCalendarSource()
        settings = SettingsStore(defaultAllCalendars: true)
        _agenda = State(initialValue: AgendaModel(source: source, settings: settings, calendar: .autoupdatingCurrent))
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            AgendaScreen(model: agenda, source: source, settings: settings)
                .task { await agenda.run() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        agenda.requestRefresh()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification),
                    perform: { _ in
                        agenda.requestRefresh()
                    },
                )
        }
    }

    // MARK: Private

    @Environment(\.scenePhase)
    private var scenePhase
    @State private var agenda: AgendaModel

    private let source: EventKitCalendarSource
    private let settings: SettingsStore
}
