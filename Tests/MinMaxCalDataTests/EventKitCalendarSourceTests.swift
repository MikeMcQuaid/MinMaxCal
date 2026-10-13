import EventKit
import Foundation
@testable import MinMaxCalData
import Synchronization
import Testing

@MainActor
struct EventKitCalendarSourceTests {
    // MARK: Internal

    @Test
    func `defers store creation to the calendar actor and reuses it`() async {
        let initialisations = Mutex<[Bool]>([])
        let source = EventKitCalendarSource(makeStore: {
            initialisations.withLock { $0.append(Thread.isMainThread) }
            return EKEventStore()
        })

        #expect(initialisations.withLock { $0.isEmpty } == true)
        let first = await Self.storeIdentity(source)
        #expect(await Self.storeIdentity(source) == first)
        #expect(initialisations.withLock { $0 } == [false])
    }

    // MARK: Private

    private static func storeIdentity(_ source: isolated EventKitCalendarSource) -> ObjectIdentifier {
        ObjectIdentifier(source.store)
    }
}
