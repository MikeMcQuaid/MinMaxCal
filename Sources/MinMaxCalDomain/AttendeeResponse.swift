public enum AttendeeResponse: String, Codable, Hashable, Sendable {
    case accepted
    case declined
    case pending
    case tentative
    case unknown
}
