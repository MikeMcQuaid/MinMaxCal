@testable import MinMaxCalCoachingDomain
import Testing

@Test
func `uncertain microphone attribution suppresses coaching`() {
    var meeting = Meeting(title: "Uncertain attribution")
    meeting.duration = 80
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 70),
        .init(speakerID: "unverified-microphone", start: 70, end: 80),
    ]
    #expect(ConversationBalance(
        meeting: meeting,
        targetShare: 0.1,
        turnLimit: 1,
    ).needsRoom == false)
    #expect(ConversationBalance(
        meeting: meeting,
        targetShare: 0.1,
        turnLimit: 1,
    ).isReliable == false)
    #expect(meeting.name(for: "unverified-microphone") == "Unverified microphone")
    meeting.duration = 400
    meeting.segments.append(.init(speakerID: "me", start: 320, end: 400))
    #expect(ConversationBalance(
        meeting: meeting,
        targetShare: 0.1,
        turnLimit: 1,
    ).isReliable)
    #expect(ConversationBalance(
        meeting: meeting,
        targetShare: 0.1,
        turnLimit: 1,
    ).needsRoom)
}

@Test
func `cues wait for enough speech`() {
    var meeting = Meeting(title: "Opening")
    meeting.duration = 10
    meeting.segments = [.init(speakerID: "me", start: 0, end: 10)]
    #expect(ConversationBalance(
        meeting: meeting,
        targetShare: 0.4,
        turnLimit: 60,
    ).needsRoom == false)
}

@Test
func `recent improvement is visible`() {
    var meeting = Meeting(title: "Leave room")
    meeting.duration = 600
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 300),
        .init(speakerID: "speaker-1", start: 300, end: 600),
    ]
    let balance = ConversationBalance(
        meeting: meeting,
        targetShare: 0.4,
        turnLimit: 60,
    )
    #expect(balance.recentShare == 0)
    #expect(balance.currentTurn == 0)
    #expect(balance.needsRoom == false)
}

@Test
func `long turns prompt A pause`() {
    var meeting = Meeting(title: "Long turn")
    meeting.duration = 80
    meeting.segments = [.init(speakerID: "me", start: 0, end: 80)]
    let balance = ConversationBalance(
        meeting: meeting,
        targetShare: 1,
        turnLimit: 60,
    )
    #expect(balance.currentTurn == 80)
    #expect(balance.needsRoom)
}

@Test
func `silence and overlap end current turn`() {
    var meeting = Meeting(title: "Pause")
    meeting.duration = 80
    meeting.segments = [.init(speakerID: "me", start: 0, end: 60)]
    #expect(MeetingStatistics(meeting: meeting).speakers[0].currentTurn == 0)
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 80),
        .init(speakerID: "speaker-1", start: 79.8, end: 80),
    ]
    #expect(MeetingStatistics(meeting: meeting).speakers[0].currentTurn == 0)
}
