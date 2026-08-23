public struct AccessStatus: Hashable, Sendable {
    // MARK: Lifecycle

    public init(events: Grant, reminders: Grant) {
        self.events = events
        self.reminders = reminders
    }

    // MARK: Public

    public enum Grant: Hashable, Sendable {
        case denied
        case full
        case notDetermined
        case restricted
        case writeOnly

        // MARK: Public

        public var isFull: Bool {
            self == .full
        }
    }

    public static let notDetermined: Self = .init(events: .notDetermined, reminders: .notDetermined)

    public var events: Grant
    public var reminders: Grant
}
