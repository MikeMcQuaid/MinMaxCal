import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct SettingsModelTests {
    // MARK: Lifecycle

    init() throws {
        store = try Fixtures.settingsStore()
        model = SettingsModel(source: source, store: store, loginItem: loginItem)
    }

    // MARK: Internal

    @Test
    func `groups lists by account and kind`() async {
        let personal = CalendarList(
            identifier: "p",
            title: "Personal",
            colour: .grey,
            kind: .event,
            accountName: "iCloud",
        )
        source.availableLists = [Fixtures.work, personal, Fixtures.list]

        await model.load()

        #expect(model.groups.map(\.account) == ["Work", "iCloud"])
        #expect(model.groups.map(\.lists) == [[Fixtures.work], [personal, Fixtures.list]])
    }

    @Test
    func `selection bindings write through to the store`() {
        let binding = model.isSelected(Fixtures.work)
        #expect(binding.wrappedValue)

        binding.wrappedValue = false

        #expect(store.selection.calendarIdentifiers.contains(Fixtures.work.identifier) == false)
    }

    @Test
    func `registers the login item once on the installed copy`() {
        model.registerLoginItemOnFirstInstalledLaunch()
        #expect(loginItem.status == .enabled)
        #expect(store.hasRegisteredLoginItem)

        model.launchAtLogin = false
        model.registerLoginItemOnFirstInstalledLaunch()

        #expect(loginItem.status == .notRegistered)
    }

    @Test
    func `development builds never register`() {
        loginItem.isInstalledCopy = false
        model.registerLoginItemOnFirstInstalledLaunch()
        #expect(loginItem.status == .notRegistered)
        #expect(store.hasRegisteredLoginItem == false)
    }

    // MARK: Private

    private let source: FakeCalendarSource = .init()
    private let loginItem: FakeLoginItem = .init()
    private let store: SettingsStore
    private let model: SettingsModel
}
