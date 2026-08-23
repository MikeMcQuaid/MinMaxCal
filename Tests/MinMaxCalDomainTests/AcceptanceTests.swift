import MinMaxCalDomain
import Testing

struct AcceptanceTests {
    // MARK: Internal

    @Test
    func `own events without attendees are accepted`() {
        #expect(Acceptance.isAccepted(organiser: nil, attendees: []))
    }

    @Test
    func `organising counts as accepting`() {
        #expect(Acceptance.isAccepted(
            organiser: Attendee(name: "Me", response: .pending, isCurrentUser: true),
            attendees: [current, other],
        ))
    }

    @Test
    func `follows the current users response`() {
        var accepted = current
        accepted.response = .accepted
        #expect(Acceptance.isAccepted(organiser: other, attendees: [accepted, other]))
        #expect(Acceptance.isAccepted(organiser: other, attendees: [current, other]) == false)
    }

    @Test
    func `someone elses acceptance does not count`() {
        #expect(Acceptance.isAccepted(organiser: nil, attendees: [other]) == false)
    }

    // MARK: Private

    private let current: Attendee = .init(name: "Me", response: .pending, isCurrentUser: true)
    private let other: Attendee = .init(name: "Other", response: .accepted)
}
