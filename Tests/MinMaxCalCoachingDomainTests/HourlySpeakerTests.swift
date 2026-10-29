import MinMaxCalCoachingDomain
import Testing

@Test
func `one to one transcripts and renamed speakers retain their hourly identities`() {
    var meeting = Meeting(title: "Planning")
    meeting.isOneToOne = true
    meeting.names["speaker-1"] = "Sam"
    meeting.transcript = [
        .init(text: "First hour.", start: 3_599, end: 3_599.5, source: .system),
        .init(text: "Second hour.", start: 3_601, end: 3_601.5, source: .system),
    ]
    #expect(meeting.transcriptTurns.map(\.speakerID) == ["speaker-1", "speaker-1@1"])
    #expect(meeting.transcriptText.contains("Speaker 1 (hour 2): Second hour."))
    meeting.names["speaker-1@1"] = "Alex"
    #expect(meeting.name(for: "speaker-1") == "Sam")
    #expect(meeting.transcriptText.contains("Alex: Second hour."))
    #expect(SpeakerIdentity.oneToOne("speaker-4@2") == "speaker-1@2")
    #expect(SpeakerIdentity.oneToOne("unverified-microphone") == "unverified-microphone")
}
