import Foundation

/// Derives conservative copy mutations from a calendar snapshot and ownership ledger.
public struct SyncPlanner {
    // MARK: Lifecycle

    /// Uses explicit time and calendar values so planning performs no I/O.
    public init(
        events: [SyncEvent],
        calendars: [CalendarList],
        policies: [SyncPolicy],
        links: [SyncLink],
        interval: DateInterval,
    ) {
        self.events = events
        self.calendars = calendars
        self.policies = policies
        self.links = links
        self.interval = interval
    }

    // MARK: Public

    /// Proposes mutations for enabled, available pairs only.
    public func plan() -> SyncPlan {
        var result = SyncPlan(links: links.filter { link in
            link.end > interval.start && (link.isManaged || policies.contains { policy in
                policy.id == link.policy && policy.source == link.source.calendar && policy.destination == link
                    .destination
            })
        })
        for policy in policies where policy.isEnabled {
            guard policy.hasAvailableCalendars(in: calendars),
                  policies
                  .count(where: { $0.isEnabled && $0.source == policy.source && $0.destination == policy.destination })
                  == 1
            else {
                result.issues.append("A sync pair has missing, duplicate or unsupported calendars.")
                continue
            }

            reconcile(policy, into: &result)
            result.checkedPolicies.insert(policy.id)
        }
        let destinations = Set(policies.filter(\.isEnabled).map(\.destination))
        result.unresolved = events.filter { event in
            destinations.contains(event.identity.calendar) && event.isCopy
                && event.content.end > interval.start && event.content.start < interval.end
                && result.links.contains { $0.copy?.matches(event.identity) == true } == false
                && result.links.contains { $0.id == SyncMarker.identifier(in: event.content.notes) } == false
        }
        result.assessments = policies.filter { result.checkedPolicies.contains($0.id) }.flatMap { policy in
            events.filter { event in event.identity.calendar == policy.source
                && event.content.end > interval.start && event.content.start < interval.end
            }
            .map { event in
                SyncAssessment(policy: policy.id, event: event, outcome: assess(event, for: policy, plan: result))
            }
        }
        return result
    }

    // MARK: Internal

    let events: [SyncEvent]
    let calendars: [CalendarList]
    let policies: [SyncPolicy]
    let links: [SyncLink]
    let interval: DateInterval

    func reconcile(_ policy: SyncPolicy, into result: inout SyncPlan) {
        let sources = events.filter { $0.identity.calendar == policy.source && isOriginal($0) }
        for link in result.links where link.policy == policy.id {
            guard link.destination == policy.destination, link.source.calendar == policy.source else {
                continue
            }

            let matches = sources.filter { link.source.matches($0.identity) }
            guard matches.count <= 1 else {
                result.issues.append("An original event has more than one matching identity.")
                continue
            }

            maintain(link, source: matches.first, policy: policy, into: &result)
        }
        for source in sources where source.isEligible(for: policy, in: interval) {
            guard result.links.contains(where: { link in
                (link.policy == policy.id && link.destination == policy.destination
                    && link.source.matches(source.identity))
                    || (link.destination == policy.destination && source.identity.external != nil
                        && link.source.external == source.identity.external
                        && link.source.occurrence == source.identity.occurrence
                        && policies.contains { $0.id == link.policy && $0.isEnabled })
            }) == false else {
                continue
            }

            let link = SyncLink(
                policy: policy.id,
                source: source.identity,
                destination: policy.destination,
                end: source.content.end,
            )
            result.links.append(link)
            maintain(link, source: source, policy: policy, into: &result)
        }
    }

    func sameInvitation(_ source: SyncEvent, _ target: SyncEvent) -> Bool {
        source.identity.external != nil && source.identity.external == target.identity.external
            && source.identity.occurrence == target.identity.occurrence
    }

    func sameTime(_ source: SyncEvent, _ target: SyncEvent) -> Bool {
        source.content.start == target.content.start && source.content.end == target.content.end
            && source.content.isAllDay == target.content.isAllDay
    }

    func migrationSources(for copy: SyncEvent) -> [SyncEvent] {
        let sources = Set(policies.filter { $0.destination == copy.identity.calendar }.map(\.source))
        let matches = events.filter { event in
            sources.contains(event.identity.calendar) && sameTime(event, copy) && isOriginal(event)
        }
        if let original = SyncMarker.legacySourceIdentifier(in: copy.identity.external) {
            return matches
                .filter { $0.identity.external == original && $0.identity.occurrence == copy.identity.occurrence }
        }
        let invitations = matches.filter { sameInvitation($0, copy) }
        return invitations.isEmpty ? matches : invitations
    }

    func isOriginal(_ event: SyncEvent) -> Bool {
        event.isCopy == false && links.contains { $0.copy?.matches(event.identity) == true } == false
    }
}
