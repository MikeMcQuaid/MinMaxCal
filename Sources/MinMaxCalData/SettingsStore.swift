import Foundation
import MinMaxCalDomain

/// The app's own settings in `UserDefaults`, and a stream of their changes.
@preconcurrency
@MainActor
public final class SettingsStore {
    // MARK: Lifecycle

    /// Uses the standard defaults unless a suite is given, as the tests do.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Public

    /// Fires whenever any value in the defaults changes; subscribe before writing.
    public var changes: AsyncStream<Void> {
        let identity = ObjectIdentifier(defaults)
        return AsyncStream { continuation in
            let task = Task {
                let notifications = NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification)
                for await notification in notifications where Self.identity(of: notification) == identity {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The selected calendars and reminder lists.
    public var selection: Selection {
        get { decode(Key.selection) ?? .empty }
        set { encode(newValue, for: Key.selection) }
    }

    /// The generic titles and Jitsi hosts.
    public var matchingRules: MatchingRules {
        get { decode(Key.matchingRules) ?? .default }
        set { encode(newValue, for: Key.matchingRules) }
    }

    /// The takeover switches and snooze durations.
    public var takeover: TakeoverSettings {
        get { decode(Key.takeover) ?? .default }
        set { encode(newValue, for: Key.takeover) }
    }

    /// The menu bar title length, clamped to `MenuBarTitle.limitRange`.
    public var titleLimit: Int {
        get {
            let stored = defaults.integer(forKey: Key.titleLimit)
            return MenuBarTitle.limitRange.contains(stored) ? stored : MenuBarTitle.defaultLimit
        }
        set { defaults.set(newValue, forKey: Key.titleLimit) }
    }

    /// Whether the first-launch login item registration has happened.
    public var hasRegisteredLoginItem: Bool {
        get { defaults.bool(forKey: Key.loginItemRegistered) }
        set { defaults.set(newValue, forKey: Key.loginItemRegistered) }
    }

    // MARK: Private

    private enum Key {
        static let selection = "selection"
        static let matchingRules = "matchingRules"
        static let takeover = "takeover"
        static let titleLimit = "titleLimit"
        static let loginItemRegistered = "loginItemRegistered"
    }

    private let defaults: UserDefaults

    private static func identity(of notification: Notification) -> ObjectIdentifier? {
        notification.object.map { ObjectIdentifier($0 as AnyObject) }
    }

    private func decode<Value: Decodable>(_ key: String) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }

    private func encode(_ value: some Encodable, for key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
