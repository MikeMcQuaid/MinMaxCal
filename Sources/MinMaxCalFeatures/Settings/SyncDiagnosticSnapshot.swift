import Foundation
import MinMaxCalDomain

struct SyncDiagnosticSnapshot: Encodable {
    // MARK: Lifecycle

    init(
        interval: DateInterval,
        calendars: [CalendarList],
        events: [SyncEvent],
        inputLinks: [SyncLink],
        plan: SyncPlan,
    ) {
        self.interval = interval
        self.calendars = calendars
        self.events = events
        self.inputLinks = inputLinks
        self.plan = plan
        counts = Dictionary(uniqueKeysWithValues: SyncWrite.Action.allCases.map { action in
            (action.rawValue, plan.writes.count { $0.action == action })
        })
        counts["No changes"] = plan.noChangeCount()
        counts["Unmatched copies left unchanged"] = plan.unresolved.count
        counts["Copying paused"] = plan.assessments.count { $0.outcome == .blocked }
    }

    // MARK: Internal

    let interval: DateInterval
    let calendars: [CalendarList]
    let events: [SyncEvent]
    let inputLinks: [SyncLink]
    let plan: SyncPlan
    var counts: [String: Int]
}
