@testable import MinMaxCalAgenda
import SwiftUI
import Testing

struct AgendaRowTests {
    @Test
    func `events reminders and all day items reserve identical time columns`() throws {
        let event = Fixtures.event("event")
        var allDay = event
        allDay.isAllDay = true
        let widths = try [event, Fixtures.reminder("reminder"), allDay].map { item in
            let renderer = ImageRenderer(content: HStack(spacing: 4) {
                AgendaRow(item: item, style: .agenda).times
            })
            return try #require(renderer.cgImage).width
        }
        #expect(widths[0] == widths[1])
        #expect(widths[0] == widths[2])
    }
}
