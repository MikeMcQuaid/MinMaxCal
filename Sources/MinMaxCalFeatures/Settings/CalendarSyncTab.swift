import MinMaxCalDomain
import SwiftUI

struct CalendarSyncTab: View {
    // MARK: Internal

    @Bindable var model: CalendarSyncModel

    let calendars: [CalendarList]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                mode
                ForEach($model.configuration.policies) { $policy in
                    SyncPolicyView(
                        policy: $policy,
                        calendars: calendars,
                        hasCopies: model.links.contains { $0.policy == policy.id && $0.isManaged },
                        canRemoveCopies: model.configuration.mode == .sync && model.isRunning == false,
                        previewRemoval: { try await model.removalPreview(for: policy.id) },
                        removeCopies: { writes in Task { await model.removeCopies(writes, for: policy.id) } },
                        removeRule: { model.configuration.policies.removeAll { $0.id == policy.id } },
                    )
                }
                Button("Add Calendar Pair", systemImage: "plus") {
                    model.configuration.policies.append(SyncPolicy())
                }
                .buttonStyle(.glass)
                .help("Choose an original calendar and a destination for its copies. New pairs start disabled.")
                SyncReportView(model: model, calendars: calendars)
            }
            .padding()
        }
        .defaultScrollAnchor(.top, for: .sizeChanges)
    }

    // MARK: Private

    private static let sectionSpacing: CGFloat = 20

    private var mode: some View {
        GroupBox("Calendar Mirroring") {
            VStack(alignment: .leading) {
                Picker("Mode", selection: $model.configuration.mode) {
                    Text("Off").tag(SyncSettings.Mode.off)
                    Text("Compare").tag(SyncSettings.Mode.compare)
                    Text("Sync").tag(SyncSettings.Mode.sync)
                }
                .pickerStyle(.segmented)
                Text("Off pauses changes. Compare previews them. Sync creates, updates and removes copies.")
                Text("Sync maintains ongoing events and the next month while this app runs, on one Mac only.")
                Text("Stop other tools syncing these pairs before choosing Sync. Originals are never changed.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
