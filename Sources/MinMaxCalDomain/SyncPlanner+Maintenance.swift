import Foundation

extension SyncPlanner {
    func maintain(_ stored: SyncLink, source: SyncEvent?, policy: SyncPolicy, into result: inout SyncPlan) {
        var link = stored
        let targets = events.filter { event in
            event.identity.calendar == link.destination
                &&
                (link.copy?.matches(event.identity) == true || SyncMarker
                    .identifier(in: event.content.notes) == link.id)
        }
        guard targets.count <= 1 else {
            result.issues.append("More than one copy has the same tracking identity.")
            return
        }

        var target = targets.first
        if target == nil, let source {
            guard recoverCopy(&link, source: source, plan: result) else {
                return
            }

            target = events.first { link.copy?.matches($0.identity) == true }
        }
        guard target.map({ $0.isOwned(by: link) }) ?? true else {
            result.issues.append("A tracked copy no longer has its ownership marker.")
            return
        }

        if source == nil || (target == nil && link.copy != nil) {
            link.missingSince = link.missingSince ?? interval.start
            replace(link, in: &result)
            guard interval.start.timeIntervalSince(link.missingSince ?? interval.start) >= Self.missingGrace else {
                return
            }
        } else {
            link.missingSince = nil
        }
        guard let source, source.isEligible(for: policy, in: interval) else {
            if let target, target.content.start < interval.end, target.content.end > interval.start {
                let reason = source?.exclusion(for: policy, in: interval)?.rawValue
                    ?? "The original is still missing after a second check at least a minute later."
                result.writes.append(.remove(link, target: target, reason: reason))
            } else if target == nil {
                result.links.removeAll { $0.id == link.id }
            }
            return
        }

        link.source = source.identity
        link.end = source.content.end
        link.copy = target?.identity
        link.missingSince = nil
        replace(link, in: &result)
        let content = source.copyContent(for: policy, id: link.id)
        if target?.content != content || target?.hasAlarms == true {
            result.writes.append(.save(link, source: source, target: target, content: content))
        }
    }

    private func recoverCopy(_ link: inout SyncLink, source: SyncEvent, plan: SyncPlan) -> Bool {
        let candidates = events.filter { $0.identity.calendar == link.destination }
        if candidates.contains(where: { sameInvitation(source, $0) && $0.isCopy == false && $0.isCancelled == false }) {
            return false
        }
        let copies = candidates.filter { $0.isCopy && sameTime(source, $0) }
        guard copies.isEmpty == false else {
            return true
        }

        let identified = copies.filter { copy in
            source.identity.external != nil
                && SyncMarker.legacySourceIdentifier(in: copy.identity.external) == source.identity.external
        }
        let matches = identified.isEmpty ? copies : identified
        guard matches.count == 1, let candidate = matches.first,
              candidate.hasAttendees == false, SyncMarker.isLegacy(candidate.content.notes),
              SyncMarker.containsMarker(candidate.content.notes) == false,
              migrationSources(for: candidate) == [source],
              plan.links.contains(where: { $0.id != link.id && $0.copy?.matches(candidate.identity) == true }) == false
        else {
            return false
        }

        link.copy = candidate.identity
        return true
    }

    private static let missingGrace: TimeInterval = 60

    private func replace(_ link: SyncLink, in result: inout SyncPlan) {
        if let index = result.links.firstIndex(where: { $0.id == link.id }) {
            result.links[index] = link
        }
    }
}
