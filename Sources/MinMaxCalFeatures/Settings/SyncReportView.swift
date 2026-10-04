import MinMaxCalDomain
import SwiftUI

struct SyncReportView: View {
    // MARK: Internal

    @Bindable var model: CalendarSyncModel

    let calendars: [CalendarList]

    var body: some View {
        GroupBox("Last Check") {
            VStack(alignment: .leading) {
                Text(checkStatus)
                actions
                SyncRehearsalView(model: model)
                comparison
                ForEach(Array(Set(model.report.issues)).sorted(), id: \.self) { issue in
                    Text(issue).foregroundStyle(.secondary)
                }
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                cleanup
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("Remove this copy?", isPresented: Binding(
            get: { removal != nil }, set: { presented in
                if presented == false {
                    removal = nil
                }
            },
        )) {
            if let removal {
                Button("Remove Copy", role: .destructive) { Task { await model.removeLegacy(removal) } }
            }
        } message: {
            Text("MinMaxCal could not identify its original event. Check the calendar and time before removing it.")
        }
    }

    // MARK: Private

    @State private var removal: SyncEvent?

    private var checkDisabled: Bool {
        model.configuration.mode == .off || model.isRunning
            || model.configuration.policies.contains(where: \.isEnabled) == false
    }

    private var checkStatus: String {
        if model.configuration.mode == .off {
            "Sync is off. Choose Compare to inspect your calendar pairs."
        } else if model.configuration.policies.contains(where: \.isEnabled) == false {
            "No calendar pairs enabled. Turn on Enable this pair to check it."
        } else if model.isRunning {
            "Checking calendars…"
        } else if model.lastChecked == nil {
            "No check completed. Choose Check Now."
        } else {
            "Showing the last completed check."
        }
    }

    private var actions: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Check Now", systemImage: "arrow.clockwise") { model.requestRefresh() }
                    .buttonStyle(.glass)
                    .disabled(checkDisabled)
                SyncExportButton(model: model)
            }
            if model.configuration.mode == .compare {
                Button("Check Proposed Changes", systemImage: "checkmark.circle") {
                    Task { await model.refresh(rehearsing: true) }
                }
                .buttonStyle(.glass)
                .disabled(checkDisabled)
                Text("Check Proposed Changes validates events and permissions without saving or deleting anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Check Now refreshes this report. In Sync mode it also applies the changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var comparison: some View {
        if let checked = model.lastChecked {
            VStack(alignment: .leading) {
                Text(checked, format: .dateTime.day().month().hour().minute())
                Text("Ongoing events and the next calendar month.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            proposedChanges
            ForEach(model.configuration.policies.filter(\.isEnabled)) { policy in
                SyncPairReportView(
                    policy: policy, report: model.report, calendars: calendars, rehearsal: model.rehearsal,
                )
            }
        }
    }

    @ViewBuilder private var proposedChanges: some View {
        VStack(alignment: .leading) {
            SyncActionsView(writes: model.report.writes, showDetails: false, rehearsal: nil)
            LabeledContent("No changes", value: String(model.report.noChangeCount()))
        }
        LabeledContent("Unmatched copies left unchanged", value: String(model.report.unresolved.count))
    }

    @ViewBuilder private var cleanup: some View {
        let copies = model.report.unresolved.filter { SyncMarker.isLegacy($0.content.notes) }
        if model.configuration.mode == .sync, copies.isEmpty == false {
            DisclosureGroup("Review Unmatched Copies for Removal") {
                ForEach(copies, id: \.identity) { event in
                    HStack {
                        detail("Unmatched copy", event: event, calendar: event.identity.calendar)
                        Spacer()
                        Button { removal = event } label: { Label("Remove", systemImage: "trash") }
                            .buttonStyle(GlassIconButtonStyle())
                            .help("Remove this unmatched copy")
                            .disabled(model.isRunning)
                    }
                }
            }
        }
    }

    private func detail(_ action: String, event: SyncEvent, calendar: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(action): \(event.content.title)")
            Text(calendars.first { $0.identifier == calendar }
                .map { "\($0.accountName) · \($0.title)" } ?? "Unavailable calendar")
            Text(event.content.start, format: .dateTime.day().month().hour().minute())
            Text(event.content.end, format: .dateTime.day().month().hour().minute())
        }
        .font(.caption)
    }
}
