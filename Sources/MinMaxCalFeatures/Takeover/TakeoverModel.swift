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
    }

    // MARK: Public

    /// The takeover on screen, or nil.
    public private(set) var current: Takeover?
    /// The next takeover the scheduler is waiting for.
    public private(set) var planned: Takeover?
    /// Why the last Complete failed, shown in the panel until the next action.
    public private(set) var errorMessage: String?
    /// Called after every action so the agenda can rebuild and re-plan.
    public var onAction: () -> Void = {}

    /// The matching rules, for the views that tidy what they show.
    public var rules: MatchingRules {
        settings.matchingRules
    }

    /// The snooze durations offered, from Settings.
    public var snoozeMinutes: [Int] {
        settings.takeover.snoozeMinutes
    }

    /// Plans the next takeover from the agenda and sleeps until its moment.
    public func schedule(agenda: Agenda, now: Date) {
        alarm?.cancel()
        planned = TakeoverPlanner.next(
            agenda: agenda,
            ledger: ledger.load(),
            now: now,
            settings: settings.takeover,
            since: lastScheduledAt,
        )
        lastScheduledAt = now
        guard let planned else {
            return
        }

        alarm = Task { [clock] in
            do {
                try await Self.sleep(until: planned.moment.addingTimeInterval(-Self.armingLead), clock: clock)
                // App Nap may defer a napped app's timers by seconds; for the final minutes the app
                // asks not to be napped and sleeps strictly, so the moment itself is never late.
                let activity = ProcessInfo.processInfo.beginActivity(
                    options: .userInitiatedAllowingIdleSystemSleep,
                    reason: "A takeover is due",
                )
                defer { ProcessInfo.processInfo.endActivity(activity) }
                try await Self.sleep(until: planned.moment, clock: clock, tolerance: .zero)
            } catch {
                return
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
        presenter.show(announcing: Self.announcement(for: takeover), playing: settings.takeover.sound)
    }

    /// Shows a real agenda item as a takeover without recording anything.
    public func preview(_ item: AgendaItem) {
        let entry = Takeover.Entry(item: item, trigger: item.kind == .reminder ? .due : .start)
        present(Takeover(entries: [entry], moment: item.start, isPreview: true))
    }

    /// Hides the panel and records the dismissal.
    public func dismiss() {
        dismiss(returningFocus: true)
    }

    /// Hides the panel, records the dismissal and opens the call, which takes the front itself.
    public func join(_ link: JoinLink) {
        dismiss(returningFocus: false)
        opener.open(link, in: settings.join[link.service])
    }

    /// Completes the reminders in Reminders, then dismisses; a failure keeps the panel up with the error.
    public func complete() async {
        guard let current else {
            return
        }

        do {
            if current.isPreview == false {
                for member in current.reminders.flatMap(\.item.members) {
                    try await source.setCompleted(true, reminder: member)
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
    /// How long before its moment a takeover is armed against App Nap.
    private static let armingLeadMinutes: TimeInterval = 5
    private static let armingLead: TimeInterval = armingLeadMinutes * secondsPerMinute

    @ObservationIgnored private let source: any CalendarSource
    @ObservationIgnored private let opener: any LinkOpener
    @ObservationIgnored private let ledger: TakeoverLedgerStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let presenter: any TakeoverPresenting
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var alarm: Task<Void, Never>?
    @ObservationIgnored private var lastScheduledAt: Date?

    /// Sleeps until `moment` by the injected clock, returning at once when it has passed.
    private static func sleep(
        until moment: Date,
        clock: @Sendable () -> Date,
        tolerance: Duration? = nil,
    ) async throws {
        let delay = moment.timeIntervalSince(clock())
        if delay > 0 {
            try await Task.sleep(for: .seconds(delay), tolerance: tolerance)
        }
    }

    private static func announcement(for takeover: Takeover) -> String {
        takeover.entries
            .lazy
            .map { entry in
                switch entry.trigger {
                case .start:
                    "\(entry.item.displayTitle) is starting"

                case .due:
                    "\(entry.item.displayTitle) is due"

                case .snooze:
                    "\(entry.item.displayTitle) is due again"
                }
            }
            .joined(separator: ". ")
    }

    private func dismiss(returningFocus: Bool) {
        finish(returningFocus: returningFocus) { ledger, takeover, now in ledger.dismissing(takeover, at: now) }
    }

    private func finish(
        returningFocus: Bool = true,
        recording update: (TakeoverLedger, Takeover, Date) -> TakeoverLedger,
    ) {
        guard let takeover = current else {
            return
        }

        let actedAt = clock()
        if takeover.isPreview == false {
            ledger.save(update(ledger.load(), takeover, actedAt), at: actedAt)
        }
        current = nil
        presenter.hide(returningFocus: returningFocus)
        onAction()
    }
}
