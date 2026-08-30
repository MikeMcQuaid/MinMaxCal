import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Testing

@MainActor
struct SettingsStoreTests {
    // MARK: Lifecycle

    init() throws {
        let suite = "MinMaxCalTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        store = SettingsStore(defaults: defaults)
    }

    // MARK: Internal

    @Test
    func `starts with nothing selected and the defaults`() {
        #expect(store.selection == .empty)
        #expect(store.matchingRules == .default)
        #expect(store.takeover == .default)
        #expect(store.join == .default())
        #expect(store.titleLimit == MenuBarTitle.defaultLimit)
        #expect(store.hasRegisteredLoginItem == false)
    }

    @Test
    func `round trips every value`() {
        store.selection = Selection(calendarIdentifiers: ["a"], reminderListIdentifiers: ["b"])
        store.matchingRules = MatchingRules(genericTitles: ["Busy"], homeTerms: ["Leith"])
        store.takeover = TakeoverSettings(
            onEventStart: false,
            onReminderDue: true,
            snoozeMinutes: [1, 2],
            sound: TakeoverSound(rawValue: "Custom"),
        )
        store.join = JoinSettings(meet: "com.apple.Safari")
        store.titleLimit = 30
        store.hasRegisteredLoginItem = true

        let reloaded = SettingsStore(defaults: defaults)

        #expect(reloaded.selection == Selection(calendarIdentifiers: ["a"], reminderListIdentifiers: ["b"]))
        #expect(reloaded.matchingRules.homeTerms == ["Leith"])
        #expect(reloaded.takeover.snoozeMinutes == [1, 2])
        #expect(reloaded.takeover.sound == TakeoverSound(rawValue: "Custom"))
        #expect(reloaded.join == JoinSettings(meet: "com.apple.Safari"))
        #expect(reloaded.titleLimit == 30)
        #expect(reloaded.hasRegisteredLoginItem)
    }

    @Test
    func `reads takeover settings saved before the sound existed`() {
        defaults.set(Data(#"{"onEventStart":false,"onReminderDue":true,"snoozeMinutes":[1]}"#.utf8), forKey: "takeover")

        let reloaded = SettingsStore(defaults: defaults)

        let expected = TakeoverSettings(onEventStart: false, onReminderDue: true, snoozeMinutes: [1], sound: .default)
        #expect(reloaded.takeover == expected)
    }

    @Test
    func `keeps a silent takeover silent`() {
        store.takeover.sound = nil
        #expect(SettingsStore(defaults: defaults).takeover.sound == nil)
    }

    @Test
    func `clamps an out of range title limit`() {
        store.titleLimit = 2
        #expect(store.titleLimit == MenuBarTitle.defaultLimit)
    }

    @Test
    func `publishes changes`() async throws {
        let changes = store.changes
        async let first = changes.first { _ in true }
        try await Task.sleep(for: .milliseconds(100))
        store.titleLimit = 20
        #expect(await first != nil)
    }

    // MARK: Private

    private let defaults: UserDefaults
    private let store: SettingsStore
}
