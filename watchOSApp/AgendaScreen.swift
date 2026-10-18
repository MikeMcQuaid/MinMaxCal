import MinMaxCalAgenda
import MinMaxCalDomain
import SwiftUI

struct AgendaScreen: View {
    // MARK: Internal

    let model: AgendaModel

    var body: some View {
        NavigationStack {
            List {
                if model.access == .notDetermined {
                    ProgressView("Loading agenda…")
                } else if model.access.canReadAgenda == false {
                    Text("Allow full Calendar or Reminders access in system privacy settings to show your agenda.")
                } else {
                    if model.access.events.isFull == false || model.access.reminders.isFull == false {
                        Label("Some calendar access is missing", systemImage: "exclamationmark.triangle")
                    }
                    if model.agenda.items.isEmpty {
                        Text("Nothing upcoming today or tomorrow.")
                    } else {
                        section(
                            "Today",
                            items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) == false },
                        )
                        section("Tomorrow", items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) })
                    }
                }
            }
            .navigationTitle("MinMaxCal")
        }
    }

    // MARK: Private

    @Environment(\.calendar)
    private var calendar

    @ViewBuilder
    private func section(_ title: String, items: [AgendaItem]) -> some View {
        if items.isEmpty == false {
            Section(title) {
                ForEach(items) { item in
                    AgendaRow(item: item, style: .agenda)
                }
            }
        }
    }
}
