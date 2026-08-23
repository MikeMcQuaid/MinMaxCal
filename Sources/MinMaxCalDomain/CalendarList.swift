public struct CalendarList: Hashable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        identifier: String,
        title: String,
        colour: ListColour,
        kind: ListKind,
        accountName: String,
        provider: String = "",
        isReadOnly: Bool = false,
    ) {
        self.identifier = identifier
        self.title = title
        self.colour = colour
        self.kind = kind
        self.accountName = accountName
        self.provider = provider
        self.isReadOnly = isReadOnly
    }

    // MARK: Public

    public var identifier: String
    public var title: String
    public var colour: ListColour
    public var kind: ListKind
    public var accountName: String
    /// Where the account lives: `iCloud`, `Exchange`, `CalDAV`, `Subscribed`, `Local`, `Birthdays`.
    public var provider: String
    public var isReadOnly: Bool

    public var id: String {
        identifier
    }

    /// `Exchange · read-only`, for a calendar's second line in Settings.
    public var summary: String {
        [
            kind == .reminder ? "Reminders" : nil,
            provider.isEmpty ? nil : provider,
            isReadOnly ? "read-only" : nil,
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }
}
