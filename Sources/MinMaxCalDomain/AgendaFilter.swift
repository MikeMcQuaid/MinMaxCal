import Foundation

/// Drops what the agenda never lists.
public enum AgendaFilter {
    /// Removes cancelled, completed, declined and ended items.
    public static func upcoming(_ items: [AgendaItem], now: Date) -> [AgendaItem] {
        items.filter { item in
            item.isCancelled == false
                && item.isCompleted == false
                && item.currentUserResponse != .declined
                && item.hasEnded(at: now) == false
        }
    }
}
