import Foundation
import MinMaxCalDomain

extension CalendarSyncModel {
    func rehearse(
        _ plan: SyncPlan,
        configuration expected: SyncSettings,
    ) async -> (checked: Int, failures: [UUID: String]) {
        var checked = 0
        var failures = [UUID: String]()
        for write in plan.writes {
            guard configuration == expected, Task.isCancelled == false else {
                break
            }

            do {
                try await source.rehearseSync(write)
            } catch {
                failures[write.link.id] = error.localizedDescription
            }
            checked += 1
        }
        return (checked, failures)
    }
}
