import Foundation
@testable import MinMaxCalCoachingDomain
import Testing

@Test
func `one to one transcript keeps the other persons words together across diarisation gaps`() throws {
    var meeting = Meeting(title: "Scott / Mike")
    meeting.isOneToOne = true
    meeting.names = ["me": "Mike", "speaker-1": "Scott"]
    meeting.segments = [.init(speakerID: "speaker-1", start: 1.5, end: 2)]
    meeting.transcript = [
        .init(text: "Hello", start: 1, end: 1.4, source: .system),
        .init(text: "Mike.", start: 1.5, end: 2, source: .system),
    ]
    #expect(meeting.transcriptText == "[00:00:01] Scott: Hello Mike.")
    let decoded = try JSONDecoder().decode(
        Meeting.self,
        from: JSONEncoder().encode(meeting),
    )
    #expect(decoded.transcriptText == meeting.transcriptText)
    meeting.isOneToOne = false
    #expect(meeting.transcriptTurns.first?.speakerID == "unidentified-speaker")
}

@Test
func `microphone transcript excludes rejected echo but retains simultaneous speech`() {
    var meeting = Meeting(title: "Echo")
    meeting.segments = [
        .init(speakerID: "speaker-1", start: 0, end: 8),
        .init(speakerID: "me", start: 4, end: 5),
        .init(speakerID: "unverified-microphone", start: 6, end: 7),
    ]
    meeting.transcript = [
        .init(text: "Hello.", start: 1, end: 2, source: .system),
        .init(text: "Hello.", start: 1.1, end: 2.1, source: .microphone),
        .init(text: "Yes.", start: 4, end: 4.5, source: .microphone),
        .init(text: "Continue.", start: 6, end: 6.5, source: .microphone),
    ]
    #expect(meeting.transcriptTurns.map(\.text) == ["Hello.", "Yes.", "Continue."])
    #expect(meeting.transcriptTurns.map(\.speakerID) == ["speaker-1", "me", "unverified-microphone"])
    #expect(meeting.transcript?.count == 4)
}

@Test
func `copied transcript follows speaker names and revised diarisation`() throws {
    var meeting = Meeting(title: "Planning")
    meeting.transcript = [
        .init(text: "Hello", start: 1, end: 1.2, source: .microphone),
        .init(text: "there.", start: 1.3, end: 1.5, source: .microphone),
        .init(text: "Agreed.", start: 3, end: 3.4, source: .system),
        .init(text: "Next.", start: 6, end: 6.3, source: .system),
    ]
    #expect(meeting.transcriptText.contains("Unidentified speaker: Agreed."))
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 2),
        .init(speakerID: "speaker-1", start: 2, end: 4),
        .init(speakerID: "speaker-2", start: 5, end: 7),
    ]
    meeting.names["speaker-1"] = "Alex"
    meeting.names["speaker-2"] = "Sam"
    #expect(meeting
        .transcriptText == "[00:00:01] You: Hello there.\n\n[00:00:03] Alex: Agreed.\n\n[00:00:06] Sam: Next.")
    meeting.names["speaker-1"] = "Alex Taylor"
    #expect(meeting.transcriptText.contains("Alex Taylor: Agreed."))
    let data = try JSONEncoder().encode(meeting)
    #expect(try JSONDecoder()
        .decode(
            Meeting.self,
            from: data,
        )
        .transcriptText == meeting.transcriptText)
}

@Test
func `uncertain and overlapping transcript words do not invent a speaker identity`() {
    var meeting = Meeting(title: "Overlap")
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 3),
        .init(speakerID: "unverified-microphone", start: 3, end: 6),
        .init(speakerID: "speaker-1", start: 0, end: 6),
        .init(speakerID: "speaker-2", start: 4, end: 6),
    ]
    meeting.transcript = [
        .init(text: "One.", start: 1, end: 1.4, source: .system),
        .init(text: "Two.", start: 2, end: 2.4, source: .microphone),
        .init(text: "Three.", start: 3, end: 3.4, source: .microphone),
        .init(text: "Four.", start: 4, end: 4.4, source: .system),
    ]
    #expect(meeting.transcriptTurns.map(\.speakerID) == [
        "speaker-1",
        "me",
        "unverified-microphone",
        "overlapping-speakers",
    ])
}

@Test
func `summaries saved before transcription still load`() throws {
    let data = try JSONEncoder().encode(Meeting(title: "Older meeting"))
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    json.removeValue(forKey: "transcript")
    let decoded = try JSONDecoder().decode(
        Meeting.self,
        from: JSONSerialization.data(withJSONObject: json),
    )
    #expect(decoded.transcript == nil)
    #expect(decoded.isOneToOne == nil)
    #expect(decoded.transcriptText.isEmpty)
}
