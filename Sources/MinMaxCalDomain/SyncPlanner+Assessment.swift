extension SyncPlanner {
    func assess(_ event: SyncEvent, for policy: SyncPolicy, plan: SyncPlan) -> SyncAssessment.Outcome {
        guard isOriginal(event) else {
            return .copy
        }

        if let exclusion = event.exclusion(for: policy, in: interval) {
            return exclusion
        }
        let write = plan.writes.first { $0.link.policy == policy.id && $0.link.source.matches(event.identity) }
        if case let .save(_, _, target, _)? = write {
            guard let target else {
                return .create
            }

            return SyncMarker.isLegacy(target.content.notes) ? .adopt : .update
        }
        if events.contains(where: { candidate in
            candidate.identity.calendar == policy.destination && sameInvitation(event, candidate)
                && candidate.isCopy == false && candidate.isCancelled == false
        }) {
            return .invitation
        }
        if plan.links.contains(where: { link in link.policy != policy.id && link.destination == policy.destination
                && event.identity.external != nil && link.source.external == event.identity.external
                && link.source.occurrence == event.identity.occurrence
                && policies.contains { $0.id == link.policy && $0.isEnabled }
        }) {
            return .shared
        }
        guard let link = plan.links.first(where: { link in
            link.policy == policy.id && link.destination == policy.destination && link.source.matches(event.identity)
        }) else {
            return .blocked
        }

        if link.missingSince != nil {
            return .waiting
        }
        let targets = events.filter { candidate in candidate.identity.calendar == link.destination
            &&
            (link.copy?.matches(candidate.identity) == true || SyncMarker
                .identifier(in: candidate.content.notes) == link.id)
        }
        guard targets.count == 1, let target = targets.first, target.isOwned(by: link) else {
            return .blocked
        }

        return target.content == event.copyContent(for: policy, id: link.id) && target.hasAlarms == false
            ? .unchanged : .blocked
    }
}
