import MinMaxCalAgenda
import MinMaxCalData
import MinMaxCalDomain
import SwiftUI

struct SettingsScreen: View {
    // MARK: Internal

    let source: any CalendarSource

    // swiftformat:disable:next privateSwiftUIDynamicProperties -- injected through the memberwise initialiser
    @Bindable var store: SettingsStore

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                    }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else {
                        return
                    }

                    access = source.accessStatus()
                    lists = await source.lists()
                    for await _ in source.changes {
                        access = source.accessStatus()
                        lists = await source.lists()
                    }
                }
        }
    }

    // MARK: Private

    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.scenePhase)
    private var scenePhase
    @State private var lists: [CalendarList] = []
    @State private var access: AccessStatus = .notDetermined

    private var form: some View {
        Form {
            Section("Access") {
                LabeledContent("Calendars", value: access.events.description)
                LabeledContent("Reminders", value: access.reminders.description)
                OpenSystemSettingsLink()
            }
            Section {
                Toggle("Show all calendars and lists", isOn: $store.allCalendars)
            } footer: {
                Text("Calendar events are read-only. Reminders can be completed and undone.")
            }
            if store.allCalendars == false {
                groups("Calendars", lists: lists.filter { $0.kind == .event })
                groups("Reminders", lists: lists.filter { $0.kind == .reminder })
                if lists.isEmpty {
                    Text(
                        "No calendars or reminder lists are available. Check access above and your system accounts."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            MatchingFields(rules: $store.matchingRules)
                .textInputAutocapitalization(.never)
            Section("About") {
                LabeledContent(
                    "Version",
                    value: Bundle.main
                        .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                )
                AboutLinks()
            }
        }
    }

    private func groups(_ title: String, lists: [CalendarList]) -> some View {
        ForEach(AccountGroup.grouping(lists)) { group in
            Section("\(title) · \(group.account)") {
                ForEach(group.lists) { list in
                    CalendarToggle(list: list, isOn: Binding(
                        get: { store.selection.contains(list) },
                        set: { store.selection.set(list, selected: $0) },
                    ))
                }
            }
        }
    }
}
