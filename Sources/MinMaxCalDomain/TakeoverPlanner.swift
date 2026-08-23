import Foundation

/// Decides which takeover fires next from the agenda, the ledger and the settings.
public enum TakeoverPlanner {
    // MARK: Public

    /// The earliest takeover not yet dismissed whose moment is ahead, within the lookback or after
    /// `since`, the last time the scheduler ran, so nothing slept through is skipped. Items due at
    /// the same moment come one at a time: dismissing the first makes the next the earliest.
    public static func next(
        agenda: Agenda,
        ledger: TakeoverLedger,
        now: Date,
        settings: TakeoverSettings,
        since: Date? = nil,
    ) -> Takeover? {
        let earliestAllowed = min(now.addingTimeInterval(-TakeoverSettings.lookback), since ?? now)
        let earliest = agenda.items
            .flatMap { candidates(for: $0, ledger: ledger, settings: settings) }
            .filter { $0.moment >= earliestAllowed }
            .filter { ledger.isDismissed($0.entry.item, trigger: $0.entry.trigger, moment: $0.moment) == false }
            .min { ($0.moment, $0.entry.item.title) < ($1.moment, $1.entry.item.title) }
        return earliest.map { Takeover(entries: [$0.entry], moment: $0.moment) }
    }

    // MARK: Private

    private struct Candidate {
        var entry: Takeover.Entry
        var moment: Date
    }

    private static func candidates(
        for item: AgendaItem,
        ledger: TakeoverLedger,
        settings: TakeoverSettings,
    ) -> [Candidate] {
        guard item.isTimed, item.isCompleted == false else {
            return []
        }

        switch item.kind {
        case .event:
            guard settings.onEventStart, item.isAccepted else {
                return []
            }

            return [Candidate(entry: Takeover.Entry(item: item, trigger: .start), moment: item.start)]

        case .reminder:
            guard settings.onReminderDue else {
                return []
            }

            let due = Candidate(entry: Takeover.Entry(item: item, trigger: .due), moment: item.start)
            guard let snoozedUntil = ledger.snoozeTime(for: item) else {
                return [due]
            }

            return [due, Candidate(entry: Takeover.Entry(item: item, trigger: .snooze), moment: snoozedUntil)]
        }
    }
}
