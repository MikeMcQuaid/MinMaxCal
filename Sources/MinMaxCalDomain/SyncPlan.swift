import Foundation

public struct SyncPlan: Encodable, Sendable {
    // MARK: Lifecycle

    public init(links: [SyncLink] = [], writes: [SyncWrite] = [], unresolved: [SyncEvent] = [], issues: [String] = []) {
        self.links = links
        self.writes = writes
        self.unresolved = unresolved
        self.issues = issues
    }

    // MARK: Public

    public var links: [SyncLink]
    public var writes: [SyncWrite]
    public var unresolved: [SyncEvent]
    public var issues: [String]
    public var checkedPolicies: Set<UUID> = []
    public var assessments: [SyncAssessment] = []

    public func noChangeCount(for policy: UUID? = nil) -> Int {
        assessments.count { assessment in
            (policy == nil || assessment.policy == policy)
                && assessment.outcome != .blocked && assessment.outcome != .waiting
                && writes.contains { write in
                    write.link.policy == assessment.policy && write.link.source.matches(assessment.event.identity)
                } == false
                && links.contains { link in
                    link.policy == assessment.policy && link.source.matches(assessment.event.identity)
                        && link.missingSince != nil
                } == false
        }
    }
}
