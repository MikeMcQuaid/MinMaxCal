import SwiftUI

struct SyncRehearsalView: View {
    let model: CalendarSyncModel

    var body: some View {
        if model.configuration.mode == .compare, let rehearsal = model.rehearsal {
            if rehearsal.checked == 0 {
                LabeledContent("Proposed changes checked", value: "0")
            } else if rehearsal.failures.isEmpty {
                Text(
                    """
                    Local checks passed: \(String(rehearsal.checked)). \
                    No calendar events were saved or deleted.
                    """
                )
            } else {
                Text(
                    """
                    \(String(rehearsal.failures.count)) of \(String(rehearsal.checked)) proposed changes \
                    failed local checks. \
                    Expand the actions within each calendar pair for details.
                    """
                )
                .foregroundStyle(.red)
            }
            if rehearsal.checked > 0 {
                Text("Provider acceptance and remote syncing remain untested.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
