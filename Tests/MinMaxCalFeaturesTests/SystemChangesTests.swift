import Foundation
@testable import MinMaxCalFeatures
import Testing

@Suite(.serialized)
struct SystemChangesTests {
    @Test(arguments: [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged])
    func `yields when the clock is set the time zone changes or the day turns`(name: Notification.Name) async throws {
        let changes = SystemChanges.stream
        async let received = changes.prefix(1).reduce(0) { count, _ in count + 1 }
        try await Task.sleep(for: .milliseconds(100))
        NotificationCenter.default.post(name: name, object: nil)
        #expect(await received == 1)
    }
}
