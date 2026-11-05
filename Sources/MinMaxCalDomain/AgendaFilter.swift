import Foundation

/// Drops what the agenda never lists.
public enum AgendaFilter {
    /// Removes cancelled, completed, declined, ended and default out-of-office items.
    public static func upcoming(_ items: [AgendaItem], now: Date) -> [AgendaItem] {
        items.filter { item in
            item.isCancelled == false
                && item.isCompleted == false
                && item.currentUserResponse != .declined
                && item.hasEnded(at: now) == false
                && (item.kind == .reminder || MatchingRules.normalise(item.title) != "out of office")
        }
    }

    /// Removes events left with only a generic title after merging: a lone `Busy` block is not a
    /// meeting, and several of them never combine into one.
    public static func named(_ items: [AgendaItem], rules: MatchingRules) -> [AgendaItem] {
        items.filter { $0.kind == .reminder || rules.isGeneric($0.title) == false }
    }
}
