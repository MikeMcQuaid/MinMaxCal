import Foundation
@testable import MinMaxCalCoachingDomain
import Testing

@Test
func `calendar guesses prefer current meetings then imminent meetings`() {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    func event(
        _ id: String,
        start: TimeInterval,
        end: TimeInterval,
    ) -> CalendarMeeting {
        CalendarMeeting(
            id: id,
            title: id,
            calendarName: "Work",
            start: now.addingTimeInterval(start),
            end: now.addingTimeInterval(end),
            participantNames: [],
        )
    }
    let events = [
        event("later", start: 601, end: 1_800),
        event("ending now", start: -1_800, end: 0),
        event("soon", start: 60, end: 1_800),
        event("ongoing", start: -3_600, end: 600),
        event("current", start: -300, end: 600),
        event("just started", start: 0, end: 600),
        event("ten minutes", start: 600, end: 1_800),
        event("invalid", start: 300, end: 200),
    ]
    #expect(CalendarMeeting.suggestions(
        from: events,
        at: now,
    )
    .map(\.id) == [
        "just started", "current", "ongoing", "soon", "ten minutes",
    ])
}

@Test
func `calendar name suggestions survive saving without assigning identities`() throws {
    var meeting = Meeting(title: "Planning")
    meeting.calendarParticipantNames = ["Alex", "Sam"]
    meeting.names["me"] = "Mike"
    meeting.segments = [.init(speakerID: "speaker-1", start: 0, end: 5)]
    #expect(meeting.name(for: "speaker-1") == "Speaker 1")
    let data = try JSONEncoder().encode(meeting)
    #expect(try JSONDecoder().decode(
        Meeting.self,
        from: data,
    ) == meeting)
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    json.removeValue(forKey: "calendarParticipantNames")
    let older = try JSONDecoder().decode(
        Meeting.self,
        from: JSONSerialization.data(withJSONObject: json),
    )
    #expect(older.calendarParticipantNames == nil)
    #expect(older.names["me"] == "Mike")
}

@Test
func `linked events without invitees are inferred meetings`() {
    let now = Date.now
    let meeting = CalendarMeeting(
        id: "linked",
        title: "Planning",
        calendarName: "Work",
        start: now,
        end: now.addingTimeInterval(600),
        participantNames: [],
        meetingURL: URL(string: "https://meet.jit.si/Planning"),
    )
    #expect(CalendarMeeting.inferred(from: [meeting], at: now) == [meeting])
}
