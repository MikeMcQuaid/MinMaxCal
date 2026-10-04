import MinMaxCalDomain
import SwiftUI

struct SyncActionsView: View {
    let writes: [SyncWrite]
    let showDetails: Bool
    let rehearsal: (checked: Int, failures: [UUID: String])?

    var body: some View {
        ForEach(SyncWrite.Action.allCases, id: \.self) { action in
            let matches = writes.filter { $0.action == action }
            if showDetails, matches.isEmpty == false {
                DisclosureGroup {
                    ForEach(Array(matches.enumerated()), id: \.offset) { _, write in
                        SyncChangesView(write: write)
                        if let rehearsal {
                            if let error = rehearsal.failures[write.link.id] {
                                Text(error).foregroundStyle(.red)
                            } else {
                                Text("Local checks passed; calendar write not attempted.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } label: {
                    LabeledContent(action.rawValue, value: String(matches.count))
                }
            } else if showDetails == false {
                LabeledContent(action.rawValue, value: String(matches.count))
            }
        }
    }
}
