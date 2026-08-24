import Foundation

/// Renders the menu bar text: the next timed item's title and countdown.
public enum MenuBarTitle {
    // MARK: Public

    /// The title length used until Settings changes it.
    public static let defaultLimit = 24
    /// The title lengths Settings allows.
    public static let limitRange = minimumLimit ... maximumLimit

    /// The title with its countdown, or nil when nothing timed is upcoming.
    public static func render(agenda: Agenda, now: Date, limit: Int = defaultLimit) -> String? {
        guard let item = nextItem(in: agenda, now: now) else {
            return nil
        }

        return "\(truncate(item.title, limit: limit)) \(Countdown.text(for: item, now: now))"
    }

    /// The first timed item: an event that has not ended or a reminder no more than one hour overdue.
    public static func nextItem(in agenda: Agenda, now: Date) -> AgendaItem? {
        agenda.items.first { item in
            item.isTimed
                && item.isCompleted == false
                && item.hasEnded(at: now) == false
                && (item.kind != .reminder || now.timeIntervalSince(item.start) <= reminderOverdueLimit)
        }
    }

    /// Keeps the head and tail of a title over `limit` grapheme clusters, with an ellipsis between.
    public static func truncate(_ title: String, limit: Int) -> String {
        let characters = Array(title.trimmingCharacters(in: .whitespacesAndNewlines))
        guard characters.count > limit else {
            return String(characters)
        }

        let head = (limit + halves) / halves
        let tail = max(0, limit - 1 - head)
        return String(characters.prefix(head)) + "…" + String(characters.suffix(tail))
    }

    // MARK: Private

    private static let minimumLimit = 8
    private static let maximumLimit = 60
    private static let halves = 2
    private static let reminderOverdueLimit: TimeInterval = 3_600
}
