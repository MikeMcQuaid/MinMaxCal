import Foundation
import MinMaxCalData
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct SettingsModelTests {
    // MARK: Lifecycle

    init() throws {
        store = try Fixtures.settingsStore()
        model = SettingsModel(source: source, store: store, loginItem: loginItem, opener: opener)
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

        #expect(model.calendarGroups.map(\.account) == ["Work", "iCloud"])
        #expect(model.reminderGroups.map(\.lists) == [[Fixtures.list]])
    }

    @Test
    func `offers the installed sounds`() async {
        await model.load()
        #expect(model.sounds.contains(.default))
    }

    @Test
    func `offers the installed apps and keeps a missing choice visible`() async {
        opener.installed = [JoinApp(bundleIdentifier: "com.apple.Safari", name: "Safari")]

        await model.load()

        #expect(model.joinApps(for: .other).map(\.name) == ["Safari"])
        #expect(model.joinApps(for: .meet).map(\.name) == ["Safari", "Microsoft Edge (not installed)"])
    }

    @Test
    func `app bindings write through to the store`() {
        model.app(for: .zoom).wrappedValue = "com.apple.Safari"
        #expect(store.join.zoom == "com.apple.Safari")
        #expect(model.app(for: .meet).wrappedValue == JoinApp.edge.bundleIdentifier)
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
    private let opener: FakeLinkOpener = .init()
    private let store: SettingsStore
    private let model: SettingsModel
}
