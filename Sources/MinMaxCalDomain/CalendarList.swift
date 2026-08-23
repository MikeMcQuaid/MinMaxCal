public struct CalendarList: Hashable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(identifier: String, title: String, colour: ListColour, kind: ListKind, accountName: String) {
        self.identifier = identifier
        self.title = title
        self.colour = colour
        self.kind = kind
        self.accountName = accountName
    }

    // MARK: Public

    public var identifier: String
    public var title: String
    public var colour: ListColour
    public var kind: ListKind
    public var accountName: String

    public var id: String {
        identifier
    }
}
