import Foundation

extension AgendaMerger {
    static func foldSyncCopies(_ items: [AgendaItem], links: [SyncLink]) -> [AgendaItem] {
        var result = items
        for link in links {
            let originals = result.indices.filter { matches(link.source, item: result[$0]) }
            let copies = result.indices.filter { index in
                let item = result[index]
                return item.kind == .event && item.calendars.contains { $0.identifier == link.destination }
                    && (SyncMarker.identifier(in: item.notes) == link.id
                        || (link.copy.map { matches($0, item: item) } == true && SyncMarker.isLegacy(item.notes)))
            }
            guard originals.count == 1, copies.count == 1,
                  let original = originals.first, let copy = copies.first, original != copy
            else {
                continue
            }

            result[original].members += result[copy].members
            for calendar in result[copy].calendars {
                guard result[original].calendars.contains(where: { $0.identifier == calendar.identifier }) == false
                else {
                    continue
                }

                result[original].calendars.append(calendar)
            }
            result.remove(at: copy)
        }
        return result
    }

    private static func matches(_ identity: SyncIdentity, item: AgendaItem) -> Bool {
        item.kind == .event && item.calendars.contains { $0.identifier == identity.calendar }
            && item.members.contains { member in
                (identity.occurrence == nil || member.occurrenceDate == identity.occurrence)
                    && (member.calendarItemIdentifier == identity.item
                        || (identity.external != nil && identity.external == item.inviteIdentifier))
            }
    }
}
