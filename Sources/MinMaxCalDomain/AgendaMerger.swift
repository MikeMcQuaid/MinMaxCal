import Foundation

/// Folds copies of the same meeting across calendars into one item.
public enum AgendaMerger {
    // MARK: Public

    /// Groups by invitation identifier, then by matching titles and exact or similar timing.
    public static func merge(_ items: [AgendaItem], rules: MatchingRules, syncLinks: [SyncLink] = []) -> [AgendaItem] {
        let units = groupedByInvite(foldSyncCopies(items, links: syncLinks))
            .flatMap { splitBySpecificTitle($0, rules: rules) }
        return mergedByTiming(units, rules: rules).map { combine($0, rules: rules) }
    }

    // MARK: Private

    private struct Timing: Hashable {
        var start: Date
        var end: Date?
    }

    private static let durationTolerance = 0.5

    private static func groupedByInvite(_ items: [AgendaItem]) -> [[AgendaItem]] {
        var groups = [[AgendaItem]]()
        var indexByInvite = [MemberIdentity: Int]()
        for item in items {
            guard item.kind == .event, let invite = item.inviteIdentifier else {
                groups.append([item])
                continue
            }

            let key = MemberIdentity(calendarItemIdentifier: invite, occurrenceDate: item.recurrenceDate)
            if let index = indexByInvite[key] {
                groups[index].append(item)
            } else {
                indexByInvite[key] = groups.count
                groups.append([item])
            }
        }
        return groups
    }

    private static func splitBySpecificTitle(_ group: [AgendaItem], rules: MatchingRules) -> [[AgendaItem]] {
        var specificTitles = [String]()
        for item in group where rules.isGeneric(item.title) == false {
            let title = MatchingRules.normalise(item.title)
            if specificTitles.contains(title) == false {
                specificTitles.append(title)
            }
        }
        guard specificTitles.count > 1 else {
            return [group]
        }

        var parts = specificTitles.map { title in group.filter { MatchingRules.normalise($0.title) == title } }
        parts[0] += group.filter { rules.isGeneric($0.title) }
        return parts
    }

    private static func mergedByTiming(_ units: [[AgendaItem]], rules: MatchingRules) -> [[AgendaItem]] {
        var merged = [[AgendaItem]]()
        var indexesByTiming = [Timing: [Int]]()
        for unit in units {
            guard let first = unit.first, first.kind == .event else {
                merged.append(unit)
                continue
            }

            let timing = Timing(start: first.start, end: first.end)
            let title = specificTitle(of: unit, rules: rules)
            let target = indexesByTiming[timing, default: []].first { index in
                let existing = specificTitle(of: merged[index], rules: rules)
                return title == nil || existing == nil || existing == title
            } ?? merged.firstIndex { group in
                guard let other = group.first, other.kind == .event,
                      let end = first.end, let otherEnd = other.end,
                      first.start == other.start || end == otherEnd,
                      let title, title == specificTitle(of: group, rules: rules)
                else {
                    return false
                }

                let tolerance = min(end.timeIntervalSince(first.start), otherEnd.timeIntervalSince(other.start))
                    * durationTolerance
                return abs(first.start.timeIntervalSince(other.start)) <= tolerance
                    && abs(end.timeIntervalSince(otherEnd)) <= tolerance
            }
            if let target {
                indexesByTiming[timing, default: []].append(target)
                merged[target] += unit
            } else {
                indexesByTiming[timing, default: []].append(merged.count)
                merged.append(unit)
            }
        }
        return merged
    }

    private static func specificTitle(of unit: [AgendaItem], rules: MatchingRules) -> String? {
        unit.map(\.title).first { rules.isGeneric($0) == false }.map(MatchingRules.normalise)
    }

    private static func combine(_ group: [AgendaItem], rules: MatchingRules) -> AgendaItem {
        let specific = group.filter { rules.isGeneric($0.title) == false }
        let trusted = specific.isEmpty ? group : specific
        guard var item = trusted.first, group.count > 1 else {
            return group[0]
        }

        let timings = Dictionary(grouping: trusted) { Timing(start: $0.start, end: $0.end) }
            .sorted { $0.value.count > $1.value.count }
        if let preferred = timings.first, preferred.value.count > (timings.dropFirst().first?.value.count ?? 0) {
            item.start = preferred.key.start
            item.end = preferred.key.end
        } else {
            item.start = trusted.map(\.start).min() ?? item.start
            item.end = trusted.compactMap(\.end).max()
        }

        item.title = longest(trusted.map(\.title)) ?? item.title
        item.members = group.flatMap(\.members)
        item.inviteIdentifier = trusted.compactMap(\.inviteIdentifier).first
        item.calendars = group.flatMap(\.calendars).reduce(into: []) { union, calendar in
            if union.contains(where: { $0.identifier == calendar.identifier }) == false {
                union.append(calendar)
            }
        }
        item.location = trusted.compactMap(\.location).first { $0.isEmpty == false }
        let notes = trusted.compactMap(\.notes).filter { $0.isEmpty == false }
        item.notes = notes.first { NotesTidier.isFromSchedulingTool($0) == false } ?? notes.first
        item.url = trusted.compactMap(\.url).first
        item.organiser = trusted.compactMap(\.organiser).first
        item.attendees = trusted.map(\.attendees).first { $0.isEmpty == false } ?? []
        item.joinLink = trusted.compactMap(\.joinLink).first
        item.recurrence = trusted.compactMap(\.recurrence).first
        item.isAccepted = trusted.contains(where: \.isAccepted)
        item.currentUserResponse = trusted.compactMap(\.currentUserResponse).contains(.accepted)
            ? .accepted
            : trusted.compactMap(\.currentUserResponse).first
        return item
    }

    private static func longest(_ titles: [String]) -> String? {
        titles.max { $0.count < $1.count }
    }
}
