import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Observation

/// Shows, schedules and acts on takeovers, live and previewed.
@Observable
public final class TakeoverModel {
    // MARK: Lifecycle

    /// Wires the ports; `clock` is injectable so tests control time.
    @preconcurrency
    public init(
        source: any CalendarSource,
        opener: any LinkOpener,
        ledger: TakeoverLedgerStore,
        settings: SettingsStore,
        presenter: any TakeoverPresenting,
        clock: @escaping @Sendable () -> Date = { Date() },
    ) {
        self.source = source
        self.opener = opener
        self.ledger = ledger
        self.settings = settings
        self.presenter = presenter
        self.clock = clock
        now = clock()
    }

    // MARK: Public

    /// The takeover on screen, or nil.
    public private(set) var current: Takeover?
    /// The next takeover the scheduler is waiting for.
    public private(set) var planned: Takeover?
    /// The clock reading the countdown renders against, refreshed every second while showing.
    public private(set) var now: Date
    /// Why the last Complete failed, shown in the panel until the next action.
    public private(set) var errorMessage: String?
    /// Called after every action so the agenda can rebuild and re-plan.
    public var onAction: () -> Void = {}

    /// The snooze durations offered, from Settings.
    public var snoozeMinutes: [Int] {
        settings.takeover.snoozeMinutes
    }

    /// Plans the next takeover from the agenda and sleeps until its moment.
    public func schedule(agenda: Agenda, now: Date) {
        alarm?.cancel()
        planned = TakeoverPlanner.next(agenda: agenda, ledger: ledger.load(), now: now, settings: settings.takeover)
        guard let planned else {
            return
        }

        alarm = Task { [clock] in
            let delay = planned.moment.timeIntervalSince(clock())
            if delay > 0 {
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
            }
            guard Task.isCancelled == false else {
                return
            }

            present(planned)
        }
    }

    /// Shows a takeover now; a live one is never replaced by a preview.
    public func present(_ takeover: Takeover) {
        if let current, current.isPreview == false, takeover.isPreview {
            return
        }
        current = takeover
        errorMessage = nil
        now = clock()
        ticker?.cancel()
        ticker = Task { [clock] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1))
                now = clock()
            }
        }
        presenter.show()
    }

    /// Shows a sample takeover that touches neither the ledger nor EventKit.
    public func preview(_ sample: AgendaItem.Sample) {
        preview(sample.item(now: clock()))
    }

    /// Shows a real agenda item as a takeover without recording anything.
    public func preview(_ item: AgendaItem) {
        let entry = Takeover.Entry(item: item, trigger: item.kind == .reminder ? .due : .start)
        present(Takeover(entries: [entry], moment: item.start, isPreview: true))
    }

    /// Hides the panel and records the dismissal.
    public func dismiss() {
        finish { ledger, takeover, now in ledger.dismissing(takeover, at: now) }
    }

    /// Hides the panel, records the dismissal and opens the call.
    public func join(_ link: JoinLink) {
        dismiss()
        opener.open(link)
    }

    /// Completes the reminders in Reminders, then dismisses; a failure keeps the panel up with the error.
    public func complete() async {
        guard let current else {
            return
        }

        do {
            if current.isPreview == false {
                for member in current.reminders.flatMap(\.item.members) {
                    try await source.complete(reminder: member)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Hides the panel and brings its reminders back after `minutes`.
    public func snooze(minutes: Int) {
        finish { ledger, takeover, now in
            ledger.snoozing(
                takeover,
                until: now.addingTimeInterval(TimeInterval(minutes) * Self.secondsPerMinute),
                at: now,
            )
        }
    }

    // MARK: Private

    private static let secondsPerMinute: TimeInterval = 60

    @ObservationIgnored private let source: any CalendarSource
    @ObservationIgnored private let opener: any LinkOpener
    @ObservationIgnored private let ledger: TakeoverLedgerStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let presenter: any TakeoverPresenting
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var alarm: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    private func finish(recording update: (TakeoverLedger, Takeover, Date) -> TakeoverLedger) {
        guard let takeover = current else {
            return
        }

        let actedAt = clock()
        if takeover.isPreview == false {
            ledger.save(update(ledger.load(), takeover, actedAt), at: actedAt)
        }
        current = nil
        ticker?.cancel()
        presenter.hide()
        onAction()
    }
}
