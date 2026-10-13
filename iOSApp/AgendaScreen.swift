import MinMaxCalAgenda
import MinMaxCalData
import MinMaxCalDomain
import SwiftUI

struct AgendaScreen: View {
    // MARK: Internal

    let model: AgendaModel
    let source: any CalendarSource
    let settings: SettingsStore

    var body: some View {
        NavigationStack {
            List {
                if model.access == .notDetermined {
                    ProgressView("Loading agenda…")
                } else if model.access.canReadAgenda == false {
                    missingAccess
                } else {
                    agenda
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationTitle("MinMaxCal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    appTitle
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showsSettings = true }
                }
            }
            .sheet(isPresented: $showsSettings) {
                SettingsScreen(source: source, store: settings)
            }
        }
    }

    // MARK: Private

    private static let titleSpacing: CGFloat = 6
    private static let rowMargin: CGFloat = 8
    private static let rowInsets: EdgeInsets = .init(top: 0, leading: rowMargin, bottom: 0, trailing: rowMargin)

    @Environment(\.calendar)
    private var calendar
    @State private var showsSettings = false
    // periphery:ignore - Read and written through the projected SwiftUI binding.
    @State private var expanded: AgendaItem.ID?

    private var appTitle: some View {
        HStack(spacing: Self.titleSpacing) {
            AppIcon()
            Text("MinMaxCal")
                .font(.headline)
        }
    }

    private var missingAccess: some View {
        ContentUnavailableView {
            Label("Calendar access needed", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Allow full Calendar or Reminders access in Settings to show your agenda.")
        } actions: {
            OpenSystemSettingsLink()
                .buttonStyle(.glass)
        }
    }

    @ViewBuilder private var agenda: some View {
        if model.access.events.isFull == false || model.access.reminders.isFull == false {
            Button("Some calendar access is missing", systemImage: "exclamationmark.triangle") {
                showsSettings = true
            }
        }
        if let message = model.errorMessage {
            Text(message)
                .foregroundStyle(.red)
        }
        if model.hasSelection == false {
            ContentUnavailableView {
                Label("No calendars selected", systemImage: "calendar")
            } description: {
                Text("Choose calendars and reminder lists in Settings.")
            } actions: {
                Button("Choose Calendars") { showsSettings = true }
                    .buttonStyle(.glass)
            }
        } else if model.agenda.items.isEmpty {
            ContentUnavailableView(
                "Nothing upcoming",
                systemImage: "calendar",
                description: Text("Events and due reminders for today and tomorrow appear here."),
            )
        } else {
            section("Today", items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) == false })
            section("Tomorrow", items: model.agenda.items.filter { calendar.isDateInTomorrow($0.start) })
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [AgendaItem]) -> some View {
        if items.isEmpty == false {
            Section(title) {
                ForEach(items) { item in
                    AgendaEntry(item: item, model: model, expanded: $expanded)
                }
                .listRowInsets(Self.rowInsets)
            }
        }
    }
}
