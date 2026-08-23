import MinMaxCalDomain
import Testing

struct TidierTests {
    @Test
    func `drops home terms and postcodes from a location but keeps the rest`() {
        let location = "Codebase, 37a Castle Terrace, Edinburgh EH1 2EL, Scotland"
        #expect(LocationTidier.display(location, rules: .default) == "Codebase, 37a Castle Terrace")
        #expect(LocationTidier.display("Edinburgh", rules: .default) == "Edinburgh")
        #expect(LocationTidier.display("Room 4, London", rules: .default) == "Room 4, London")
    }

    @Test
    func `removes zoom's rails from notes`() {
        let notes = """
        Agenda first.

        -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
        Join Zoom Meeting https://example.zoom.us/j/1?pwd=x
        Please do not edit this section. -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-.
        """
        #expect(NotesTidier.removingCallBoilerplate(from: notes) == "Agenda first.")
        #expect(NotesTidier.removingCallBoilerplate(from: "Plain notes") == "Plain notes")
    }

    @Test
    func `infers a name from a dotted address`() {
        #expect(AttendeeName.display(name: nil, email: "jane.doe@example.com") == "Jane Doe")
        #expect(AttendeeName.display(name: "jane.doe@example.com", email: "jane.doe@example.com") == "Jane Doe")
        #expect(AttendeeName.display(name: "Jane", email: "jane.doe@example.com") == "Jane")
        #expect(AttendeeName.display(name: nil, email: "jdoe@example.com") == "jdoe@example.com")
        #expect(AttendeeName.display(name: nil, email: "mary-ann.o-neil@example.com") == "Mary-Ann O-Neil")
    }

    @Test
    func `describes recurrence`() {
        #expect(Recurrence(frequency: .weekly, interval: 1).description == "Every week")
        #expect(Recurrence(frequency: .monthly, interval: 3).description == "Every 3 months")
    }
}
