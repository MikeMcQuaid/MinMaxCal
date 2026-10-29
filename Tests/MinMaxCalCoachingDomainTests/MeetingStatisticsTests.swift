@testable import MinMaxCalCoachingDomain
import Testing

@Test
func `silence does not dilute speaking share`() {
    var meeting = Meeting(title: "Stand-up")
    meeting.duration = 100
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 10),
        .init(speakerID: "speaker-1", start: 10, end: 40),
    ]
    let stats = MeetingStatistics(meeting: meeting)
    #expect(stats.speakers[0].speakingShare == 0.25)
    #expect(stats.speakers[0].meetingShare == 0.1)
    #expect(stats.silence == 60)
    #expect(stats.overlap == 0)
}

@Test
func `overlaps break turns and are counted once`() {
    var meeting = Meeting(title: "Overlapping voices")
    meeting.duration = 20
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 15),
        .init(speakerID: "me", start: 5, end: 10),
        .init(speakerID: "speaker-1", start: 5, end: 8),
        .init(speakerID: "speaker-2", start: 6, end: 9),
    ]
    let stats = MeetingStatistics(meeting: meeting)
    #expect(stats.speakers[0].speakingTime == 15)
    #expect(stats.speakers[0].longestTurn == 6)
    #expect(stats.overlap == 4)
    #expect(stats.silence == 5)
    #expect(abs(stats.speakers.reduce(0) { $0 + $1.speakingShare } - 1) < 0.0001)
}

@Test
func `brief pauses join turns unless someone else speaks`() {
    var meeting = Meeting(title: "Pauses")
    meeting.duration = 10
    meeting.segments = [
        .init(speakerID: "me", start: 0, end: 3),
        .init(speakerID: "me", start: 3.5, end: 6),
        .init(speakerID: "me", start: 6.5, end: 9),
        .init(speakerID: "speaker-1", start: 6.1, end: 6.2),
    ]
    #expect(MeetingStatistics(meeting: meeting).speakers[0].longestTurn == 6)
}

@Test
func `empty and invalid segments are safe`() {
    var meeting = Meeting(title: "Empty")
    #expect(MeetingStatistics(meeting: meeting).speakers[0].speakingShare == 0)
    meeting.duration = 10
    meeting.segments = [
        .init(speakerID: "me", start: -5, end: 5),
        .init(speakerID: "me", start: 8, end: 30),
        .init(speakerID: "me", start: .nan, end: 5),
        .init(speakerID: "me", start: 4, end: 2),
    ]
    #expect(MeetingStatistics(meeting: meeting).speakers[0].speakingTime == 7)
}
