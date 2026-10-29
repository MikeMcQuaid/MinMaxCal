public struct Attendee: Hashable, Sendable {
    // MARK: Lifecycle

    public init(name: String, response: AttendeeResponse, isCurrentUser: Bool = false, isPerson: Bool = true) {
        self.name = name
        self.response = response
        self.isCurrentUser = isCurrentUser
        self.isPerson = isPerson
    }

    // MARK: Public

    public var name: String
    public var response: AttendeeResponse
    public var isCurrentUser: Bool
    public var isPerson: Bool
}
