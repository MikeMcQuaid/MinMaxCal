import Foundation
import MinMaxCalDomain

public protocol CalendarSource: Sendable {
    var changes: AsyncStream<Void> { get }

    func requestAccess() async -> AccessStatus
    func accessStatus() -> AccessStatus
    func lists() async -> [CalendarList]
    func agenda(from start: Date, to end: Date, selection: Selection, rules: MatchingRules) async -> [AgendaItem]
    func complete(reminder: MemberIdentity) async throws
}
