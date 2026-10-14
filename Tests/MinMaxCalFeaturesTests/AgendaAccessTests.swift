import MinMaxCalAgenda
import MinMaxCalData
import MinMaxCalDomain
import Testing

struct AgendaAccessTests {
    @Test(arguments: [AccessStatus.Grant.denied, .restricted, .writeOnly, .notDetermined, .full])
    func `either readable source is enough to show the agenda`(_ grant: AccessStatus.Grant) {
        #expect(AccessStatus(events: grant, reminders: .denied).canReadAgenda == grant.isFull)
        #expect(AccessStatus(events: .denied, reminders: grant).canReadAgenda == grant.isFull)
        #expect(AccessStatus(events: grant, reminders: .full).canReadAgenda)
    }

    @Test
    func `returning from Settings refreshes permission status`() async throws {
        let source = FakeCalendarSource()
        let model = try AgendaModel(source: source, settings: Fixtures.settingsStore(), opener: FakeLinkOpener())
        await model.rebuild()
        #expect(model.access == source.access)

        source.access = AccessStatus(events: .denied, reminders: .full)
        await model.rebuild()
        #expect(model.access == source.access)
    }

    @Test
    func `all calendars follows available lists without changing the saved selection`() async throws {
        let source = FakeCalendarSource()
        let settings = try Fixtures.settingsStore()
        settings.selection = .empty
        settings.allCalendars = true
        source.availableLists = [Fixtures.work, Fixtures.list]
        let model = AgendaModel(source: source, settings: settings)

        await model.rebuild()
        #expect(source.selection == Fixtures.selection)
        #expect(model.hasSelection)
        #expect(settings.selection == .empty)

        source.availableLists = [Fixtures.list]
        await model.rebuild()
        #expect(source.selection == Selection(
            calendarIdentifiers: [],
            reminderListIdentifiers: [Fixtures.list.identifier],
        ))

        source.availableLists = []
        await model.rebuild()
        #expect(model.hasSelection == false)
        #expect(model.agenda.items.isEmpty)
    }

    @Test
    func `switching from all lists honours an empty or individual selection`() async throws {
        let source = FakeCalendarSource()
        source.availableLists = [Fixtures.work, Fixtures.list]
        let settings = try Fixtures.settingsStore()
        settings.allCalendars = true
        settings.selection = .empty
        let model = AgendaModel(source: source, settings: settings)
        await model.rebuild()
        #expect(model.hasSelection)

        settings.allCalendars = false
        await model.rebuild()
        #expect(model.hasSelection == false)
        #expect(model.agenda.items.isEmpty)

        settings.selection.set(Fixtures.work, selected: true)
        await model.rebuild()
        #expect(source.selection == Selection(
            calendarIdentifiers: [Fixtures.work.identifier],
            reminderListIdentifiers: [],
        ))
    }
}
