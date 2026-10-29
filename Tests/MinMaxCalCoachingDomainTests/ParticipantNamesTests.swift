@testable import MinMaxCalCoachingDomain
import Testing

@Test
func `one to one names use my name title and calendar email`() {
    #expect(ParticipantNames.otherPerson(
        title: "Scott / Mike",
        myName: "Mike",
        invitees: ["scott.mckinnon@getadministrate.com"],
    ) == "Scott")
    #expect(ParticipantNames.otherPerson(title: "Scott/Mike", myName: "Mike McQuaid", invitees: []) == "Scott")
    #expect(ParticipantNames.otherPerson(
        title: "Weekly catch-up",
        myName: "Mike",
        invitees: ["mike@example.com", "scott.mckinnon@example.com"],
    ) == "Scott Mckinnon")
    #expect(ParticipantNames.otherPerson(title: "Scott / Mike", myName: "", invitees: []) == nil)
    #expect(ParticipantNames.otherPerson(title: "Scott / Mike", myName: "Mike", invitees: ["Sam"]) == "Sam")
    #expect(ParticipantNames.otherPerson(title: "Scott / Mike", myName: "Mike", invitees: ["Scott", "Sam"]) == nil)
    #expect(ParticipantNames
        .otherPerson(title: "Planning", myName: "Alex", invitees: ["Alex Smith", "Alex Jones"]) == nil)
}
