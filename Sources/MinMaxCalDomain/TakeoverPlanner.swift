import Foundation

/// Decides which takeover fires next from the agenda, the ledger and the settings.
public enum TakeoverPlanner {
    // MARK: Public

    /// The earliest takeover not yet dismissed whose moment is ahead or within the lookback,
    /// grouping everything due in the same minute.
    public static func next(
        agenda: Agenda,
        ledger: TakeoverLedger,
        now: Date,
        settings: TakeoverSettings,
    ) -> Takeover? {
        let earliestAllowed = now.addingTimeInterval(-TakeoverSettings.lookback)
        let candidates = agenda.items
            .flatMap { candidates(for: $0, ledger: ledger, settings: settings) }
            .filter { $0.moment >= earliestAllowed }
            .filter { ledger.isDismissed($0.entry.item, trigger: $0.entry.trigger, moment: $0.moment) == false }
            .sorted { $0.moment < $1.moment }
        guard let earliest = candidates.first else {
            return nil
        }

        let minute = floorToMinute(earliest.moment)
        let entries = candidates.filter { floorToMinute($0.moment) == minute }.map(\.entry)
        return Takeover(entries: entries, moment: earliest.moment)
    }

    // MARK: Private

    private struct Candidate {
        var entry: Takeover.Entry
        var moment: Date
    }

    private static let secondsPerMinute: TimeInterval = 60

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

    private static func floorToMinute(_ date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: floor(date.timeIntervalSinceReferenceDate / secondsPerMinute) *
            secondsPerMinute)
    }
}
