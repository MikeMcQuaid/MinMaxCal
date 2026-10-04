import MinMaxCalDomain
import SwiftUI

struct SyncPairReportView: View {
    // MARK: Internal

    let policy: SyncPolicy
    let report: SyncPlan
    let calendars: [CalendarList]
    let rehearsal: (checked: Int, failures: [UUID: String])?

    var body: some View {
        let waiting = report.links.count { link in
            link.policy == policy.id && link.missingSince != nil && report.writes
                .contains { $0.link.id == link.id } == false
        }
        VStack(alignment: .leading) {
            Text("\(calendarName(policy.source)) → \(calendarName(policy.destination))")
                .fontWeight(.medium)
            if report.checkedPolicies.contains(policy.id) == false {
                Text("Pair could not be checked. Check its calendars and the reported issues.")
            } else {
                SyncActionsView(
                    writes: report.writes.filter { $0.link.policy == policy.id },
                    showDetails: true,
                    rehearsal: rehearsal,
                )
                LabeledContent("No changes", value: String(report.noChangeCount(for: policy.id)))
                let blocked = report.assessments.count { $0.policy == policy.id && $0.outcome == .blocked }
                if blocked > 0 {
                    LabeledContent("Copying paused", value: String(blocked))
                }
            }
            if waiting > 0 {
                Text(
                    """
                    Copies awaiting confirmation: \(String(waiting)). \
                    Check again at least a minute after they first went missing.
                    """
                )
                .font(.caption)
            }
        }
    }

    // MARK: Private

    private func calendarName(_ identifier: String) -> String {
        calendars.first { $0.identifier == identifier }
            .map { "\($0.accountName) · \($0.title)" } ?? "Unavailable calendar"
    }
}
