import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct AgendaModelTests {
    // MARK: Lifecycle

    init() throws {
        store = try Fixtures.settingsStore()
        model = AgendaModel(source: source, settings: store, opener: opener, clock: Fixtures.clock)
    }

    // MARK: Internal

    @Test
    func `rebuild filters merges sorts and renders the title`() async {
        let busy = Fixtures.event("busy", title: "Busy", startingIn: 60)
        let planning = Fixtures.event("planning", title: "Weekly planning", startingIn: 60)
        let past = Fixtures.event("past", startingIn: -90)
        let reminder = Fixtures.reminder("reminder", title: "Call back", dueIn: 10)
        source.items = [busy, planning, past, reminder]
        var rebuilt: Agenda?
        model.onRebuild = { agenda, _ in rebuilt = agenda }

        await model.rebuild()

        #expect(model.agenda.items.map(\.title) == ["Call back", "Weekly planning"])
        #expect(model.agenda.items[1].members == busy.members + planning.members)
        #expect(model.title == "Call back 10m")
        #expect(model.hasSelection)
        #expect(rebuilt == model.agenda)
    }

    @Test
    func `an empty selection gives an empty agenda and no title`() async {
        store.selection = .empty
        source.items = [Fixtures.event("e")]

        await model.rebuild()

        #expect(model.agenda.items.isEmpty)
        #expect(model.title == nil)
        #expect(model.hasSelection == false)
    }

    @Test
    func `completing removes the row and writes through`() async {
        let reminder = Fixtures.reminder("reminder")
        source.items = [reminder]
        await model.rebuild()

        await model.complete(reminder)

        #expect(model.agenda.items.isEmpty)
        #expect(source.completed == reminder.members)
        #expect(model.errorMessage == nil)
    }

    @Test
    func `a failed completion restores the row with the error`() async {
        let reminder = Fixtures.reminder("reminder")
        source.items = [reminder]
        source.completionError = FakeError()
        await model.rebuild()

        await model.complete(reminder)

        #expect(model.agenda.items == [reminder])
        #expect(model.errorMessage == "Could not save.")
    }

    @Test
    func `join opens through the port`() throws {
        let link = try JoinLink(service: .meet, url: #require(URL(string: "https://meet.google.com/abc")))
        model.join(link)
        #expect(opener.opened == [link])
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let opener: FakeLinkOpener = .init()
    private let store: SettingsStore
    private let model: AgendaModel
}
