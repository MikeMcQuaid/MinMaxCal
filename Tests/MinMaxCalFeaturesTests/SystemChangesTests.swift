import Foundation
@testable import MinMaxCalFeatures
import Testing

struct SystemChangesTests {
    @Test
    func `yields when the clock is set the time zone changes or the day turns`() async throws {
        let changes = SystemChanges.stream
        async let received = changes.prefix(3).reduce(0) { count, _ in count + 1 }
        try await Task.sleep(for: .milliseconds(100))
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            NotificationCenter.default.post(name: name, object: nil)
        }
        #expect(await received == 3)
    }
}
