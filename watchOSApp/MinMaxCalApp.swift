import MinMaxCalAgenda
import MinMaxCalData
import SwiftUI

@main
struct MinMaxCalApp: App {
    // MARK: Lifecycle

    init() {
        _agenda = State(initialValue: AgendaModel(
            source: EventKitCalendarSource(),
            settings: SettingsStore(defaultAllCalendars: true),
            powerChanges: AsyncStream { continuation in
                continuation.yield(true)
                continuation.finish()
            },
            calendar: .autoupdatingCurrent,
        ))
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            AgendaScreen(model: agenda)
                .task(id: scenePhase) {
                    if scenePhase == .active {
                        await agenda.run()
                    }
                }
        }
    }

    // MARK: Private

    @Environment(\.scenePhase)
    private var scenePhase
    @State private var agenda: AgendaModel
}
