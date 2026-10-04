public struct CalendarList: Codable, Hashable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        identifier: String,
        title: String,
        colour: ListColour,
        kind: ListKind,
        accountName: String,
        allowsChanges: Bool = false,
        supportsBusy: Bool = false,
    ) {
        self.identifier = identifier
        self.title = title
        self.colour = colour
        self.kind = kind
        self.accountName = accountName
        self.allowsChanges = allowsChanges
        self.supportsBusy = supportsBusy
    }

    // MARK: Public

    public var identifier: String
    public var title: String
    public var colour: ListColour
    public var kind: ListKind
    public var accountName: String
    public var allowsChanges: Bool
    public var supportsBusy: Bool

    public var id: String {
        identifier
    }
}
