import MinMaxCalDomain
import Testing

struct TidierTests {
    @Test
    func `drops home terms and postcodes from a location but keeps the rest`() {
        let location = "Codebase, 37a Castle Terrace, Edinburgh EH1 2EL, Scotland"
        #expect(LocationTidier.display(location, rules: .default) == "Codebase, 37a Castle Terrace")
        #expect(LocationTidier.display("Edinburgh", rules: .default) == "Edinburgh")
        #expect(LocationTidier.display("Room 4, London", rules: .default) == "Room 4, London")
        #expect(LocationTidier
            .display("Codebase\nCastle Terrace\nEdinburgh\nEdinburgh", rules: .default) == "Codebase, Castle Terrace")
        #expect(LocationTidier.display("London, london, Paris", rules: .default) == "London, Paris")
    }

    @Test
    func `removes zoom's rails from notes`() {
        let notes = """
        Agenda first.

        -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-
        Join Zoom Meeting https://example.zoom.us/j/1?pwd=x
        Please do not edit this section. -::~:~::~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~:~::~:~::-.
        """
        #expect(NotesTidier.removingBoilerplate(from: notes, hasCallLink: true) == "Agenda first.")
        #expect(NotesTidier.removingBoilerplate(from: notes, hasCallLink: false) == notes)
        #expect(NotesTidier.removingBoilerplate(from: "Plain notes", hasCallLink: true) == "Plain notes")
    }

    @Test
    func `removes zoom's event details banner and reclaim's visibility notice`() {
        let notes = """
        Prep the deck.
        ~~~~~ Event Details ~~~~~
        JJ Cranston (he/him) is inviting you to a scheduled Zoom meeting.
        Join Zoom Meeting
        https://example.zoom.us/j/1?pwd=x

        Meeting ID: 846 3823 6694
        Passcode: 440326

        ---
        This time has been blocked on your calendar and is marked as Default visibility. Others will see Busy.
        This description is visible to anyone who can view normal events on your calendar.
        """
        #expect(NotesTidier.removingBoilerplate(from: notes, hasCallLink: true) == "Prep the deck.")
        let reclaimOnly = "Focus time.\nThis time has been blocked on your calendar and is marked as Default."
        #expect(NotesTidier.removingBoilerplate(from: reclaimOnly, hasCallLink: false) == "Focus time.")
    }

    @Test
    func `infers a name from a dotted address`() {
        #expect(AttendeeName.display(name: nil, email: "jane.doe@example.com") == "Jane Doe")
        #expect(AttendeeName.display(name: "jane.doe@example.com", email: "jane.doe@example.com") == "Jane Doe")
        #expect(AttendeeName.display(name: "Jane", email: "jane.doe@example.com") == "Jane")
        #expect(AttendeeName.display(name: nil, email: "jdoe@example.com") == "jdoe@example.com")
        #expect(AttendeeName.display(name: nil, email: "mary-ann.o-neil@example.com") == "Mary-Ann O-Neil")
        #expect(AttendeeName.display(name: nil, email: "mike.mcquaid@example.com") == "Mike McQuaid")
    }

    @Test
    func `describes recurrence`() {
        #expect(Recurrence(frequency: .weekly, interval: 1).description == "Every week")
        #expect(Recurrence(frequency: .monthly, interval: 3).description == "Every 3 months")
    }
}
