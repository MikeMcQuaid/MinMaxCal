import Foundation
import MinMaxCalDomain
import Testing

struct SyncMarkerTests {
    @Test
    func `recognises legacy sync footers without treating referral codes as event identifiers`() {
        let busy = """
        <i>This event was created by
        <a href="https://app.reclaim.ai/signup?utm_source=calendar\
        &utm_campaign=calendar-referral&utm_medium=calendar-sync-event&utm_term=R5pKc">Calendar Sync</a>.</i>
        <p>This time has been blocked on your calendar and is marked as Private.
        Others will see that you are Busy at this time, and no other details.</p>
        """
        let travel = """
        <i>This event was created by
        <a href="https://app.reclaim.ai/signup?utm_source=calendar\
        &amp;utm_campaign=calendar-referral\
        &amp;utm_medium=calendar-sync-event&amp;utm_term=R5pKc">Calendar Sync</a>.</i>
        <p>Mike is on a flight and is busy at this time. Please find another time to avoid scheduling conflicts.</p>
        """
        #expect(SyncMarker.isLegacy(busy))
        #expect(SyncMarker.isLegacy(travel))
        #expect(SyncMarker.identifier(in: busy) == nil)
        #expect(SyncMarker.identifier(in: travel) == nil)
        #expect(SyncMarker.isLegacy(busy.replacing("calendar-sync-event", with: "habit")) == false)
        #expect(SyncMarker.isLegacy(busy.replacing("app.reclaim.ai", with: "app.reclaim.ai.example.com")) == false)
        #expect(SyncMarker.isLegacy("Discuss reclaim.ai at lunch") == false)
        #expect(SyncMarker.isLegacy(nil) == false)
    }

    @Test
    func `round trips an opaque footer and rejects conflicting identities`() {
        let identifier = UUID()
        #expect(SyncMarker.identifier(in: "Notes\n\n" + SyncMarker.footer(identifier)) == identifier)
        #expect(SyncMarker.identifier(in: "<p>" + SyncMarker.footer(identifier) + "</p>") == identifier)
        #expect(SyncMarker.identifier(in: SyncMarker.footer(identifier) + "\n" + SyncMarker.footer(UUID())) == nil)
        #expect(SyncMarker.identifier(in: "MinMaxCal sync: broken") == nil)
        #expect(SyncMarker.containsMarker("MinMaxCal sync: broken"))
    }
}
