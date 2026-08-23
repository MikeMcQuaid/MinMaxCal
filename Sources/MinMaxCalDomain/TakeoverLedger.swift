import Foundation

public struct TakeoverLedger: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(dismissals: [Dismissal] = [], snoozes: [Snooze] = []) {
        self.dismissals = dismissals
        self.snoozes = snoozes
    }

    // MARK: Public

    public struct Dismissal: Codable, Hashable, Sendable {
        // MARK: Lifecycle

        public init(member: MemberIdentity, trigger: TakeoverTrigger, moment: Date, recordedAt: Date) {
            self.member = member
            self.trigger = trigger
            self.moment = moment
            self.recordedAt = recordedAt
        }

        // MARK: Public

        public var member: MemberIdentity
        public var trigger: TakeoverTrigger
        public var moment: Date
        public var recordedAt: Date
    }

    public struct Snooze: Codable, Hashable, Sendable {
        // MARK: Lifecycle

        public init(member: MemberIdentity, until: Date, recordedAt: Date) {
            self.member = member
            self.until = until
            self.recordedAt = recordedAt
        }

        // MARK: Public

        public var member: MemberIdentity
        public var until: Date
        public var recordedAt: Date
    }

    public static let empty: Self = .init()
    public static let retention: TimeInterval = 86_400

    public var dismissals: [Dismissal]
    public var snoozes: [Snooze]

    public func isDismissed(_ item: AgendaItem, trigger: TakeoverTrigger, moment: Date) -> Bool {
        dismissals.contains { dismissal in
            item.members.contains(dismissal.member)
                && dismissal.trigger == trigger
                && Self.sameSecond(dismissal.moment, moment)
        }
    }

    public func snoozeTime(for item: AgendaItem) -> Date? {
        snoozes.filter { item.members.contains($0.member) }.map(\.until).max()
    }

    public func dismissing(_ takeover: Takeover, at now: Date) -> Self {
        var ledger = self
        for entry in takeover.entries {
            let moment = entry.trigger == .snooze ? snoozeTime(for: entry.item) ?? takeover.moment : takeover.moment
            ledger.dismissals += entry.item.members.map { member in
                Dismissal(member: member, trigger: entry.trigger, moment: moment, recordedAt: now)
            }
        }
        return ledger
    }

    public func snoozing(_ takeover: Takeover, until: Date, at now: Date) -> Self {
        var ledger = dismissing(takeover, at: now)
        for entry in takeover.reminders {
            ledger.snoozes += entry.item.members.map { Snooze(member: $0, until: until, recordedAt: now) }
        }
        return ledger
    }

    public func pruned(at now: Date) -> Self {
        let cutoff = now.addingTimeInterval(-Self.retention)
        return Self(
            dismissals: dismissals.filter { $0.recordedAt > cutoff },
            snoozes: snoozes.filter { $0.recordedAt > cutoff },
        )
    }

    // MARK: Private

    private static func sameSecond(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 1
    }
}
