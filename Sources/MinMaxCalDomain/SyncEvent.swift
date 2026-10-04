import Foundation

public struct SyncEvent: Codable, Equatable, Sendable {
    // MARK: Lifecycle

    public init(
        identity: SyncIdentity,
        content: SyncContent,
        isAccepted: Bool = true,
        response: AttendeeResponse? = nil,
        isCancelled: Bool = false,
        hasAttendees: Bool = false,
        hasAlarms: Bool = false,
    ) {
        self.identity = identity
        self.content = content
        self.isAccepted = isAccepted
        self.response = response
        self.isCancelled = isCancelled
        self.hasAttendees = hasAttendees
        self.hasAlarms = hasAlarms
    }

    // MARK: Public

    public var identity: SyncIdentity
    public var content: SyncContent
    public var isAccepted: Bool
    public var response: AttendeeResponse?
    public var isCancelled: Bool
    public var hasAttendees: Bool
    public var hasAlarms: Bool

    public var isCopy: Bool {
        SyncMarker.containsMarker(content.notes) || SyncMarker.isLegacy(content.notes)
    }

    public func isOwned(by link: SyncLink) -> Bool {
        identity.calendar == link.destination && hasAttendees == false
            && (SyncMarker.identifier(in: content.notes) == link.id
                || (link.copy?.matches(identity) == true && SyncMarker.isLegacy(content.notes)
                    && SyncMarker.containsMarker(content.notes) == false))
    }

    public func preventsCreation(for link: SyncLink, source: Self) -> Bool {
        identity.calendar == link.destination
            && (SyncMarker.identifier(in: content.notes) == link.id
                || (isCopy && content.start == source.content.start && content.end == source.content.end
                    && content.isAllDay == source.content.isAllDay)
                || (isCancelled == false && identity.external != nil && identity.external == source.identity.external
                    && identity.occurrence == source.identity.occurrence))
    }

    public func isEligible(for policy: SyncPolicy, in interval: DateInterval) -> Bool {
        exclusion(for: policy, in: interval) == nil
    }

    public func copyContent(for policy: SyncPolicy, id: UUID) -> SyncContent {
        var copy = content
        copy.availability = content.availabilityForCopy
        copy.notes = SyncMarker.footer(id)
        if policy.content == .original {
            copy.url = content.url.flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
            if let join = JoinLinkDetector.detect(url: content.url, location: content.location, notes: content.notes) {
                if join.url != copy.url {
                    copy.notes = join.url.absoluteString + "\n\n" + SyncMarker.footer(id)
                }
            }
        } else {
            copy.title = policy.content == .busy ? "Busy" : "Travel"
            copy.location = nil
            copy.url = nil
        }
        return copy
    }
}
