public struct Attendee: Hashable, Sendable {
    // MARK: Lifecycle

    public init(name: String, response: AttendeeResponse, isCurrentUser: Bool = false) {
        self.name = name
        self.response = response
        self.isCurrentUser = isCurrentUser
    }

    // MARK: Public

    public var name: String
    public var response: AttendeeResponse
    public var isCurrentUser: Bool
}
