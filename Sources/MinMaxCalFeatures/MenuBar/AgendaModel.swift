import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Observation

/// Owns the agenda and rebuilds it on every change, minute, wake or setting.
@Observable
public final class AgendaModel {
    // MARK: Lifecycle

    /// Wires the ports; `wake`, `clock` and `calendar` are injectable for tests.
    @preconcurrency
    public init(
        source: any CalendarSource,
        settings: SettingsStore,
        opener: any LinkOpener,
        wake: AsyncStream<Void> = AsyncStream { $0.finish() },
        clock: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current,
    ) {
        self.source = source
        self.settings = settings
        self.opener = opener
        self.wake = wake
        self.clock = clock
        self.calendar = calendar
        now = clock()
        titleLimit = settings.titleLimit
        (refreshRequests, refresh) = AsyncStream.makeStream()
    }

    // MARK: Public

    /// The current agenda: today and tomorrow, filtered, merged and sorted.
    public private(set) var agenda: Agenda = .empty
    /// The clock reading of the last rebuild.
    public private(set) var now: Date
    /// The grants the app was given at launch.
    public private(set) var access: AccessStatus = .notDetermined
    /// The menu bar title length from Settings.
    public private(set) var titleLimit: Int
    /// Whether any calendar or list is selected, for the empty state.
    public private(set) var hasSelection = false
    /// Why the last completion failed.
    public private(set) var errorMessage: String?
    /// Called with every new agenda; the app points this at the takeover scheduler.
    public var onRebuild: (Agenda, Date) -> Void = { _, _ in }

    /// The menu bar title, or nil for the icon alone.
    public var title: String? {
        MenuBarTitle.render(agenda: agenda, now: now, limit: titleLimit)
    }

    /// Requests access, then rebuilds for as long as the task lives.
    public func run() async {
        access = await source.requestAccess()
        await rebuild()
        let (triggers, trigger) = AsyncStream<Void>.makeStream()
        let feeds = [source.changes, MinuteTicks.stream(clock: clock), wake, settings.changes, refreshRequests]
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds {
                group.addTask {
                    for await _ in feed {
                        trigger.yield()
                    }
                }
            }
            for await _ in triggers {
                await rebuild()
            }
        }
    }

    /// Fetches, filters, merges and publishes the agenda once.
    public func rebuild() async {
        let rebuildTime = clock()
        now = rebuildTime
        titleLimit = settings.titleLimit
        let selection = settings.selection
        let rules = settings.matchingRules
        hasSelection = selection.isEmpty == false
        let horizon = horizon(around: rebuildTime)
        let raw = await source.agenda(from: horizon.start, to: horizon.end, selection: selection, rules: rules)
        let items = AgendaMerger.merge(AgendaFilter.upcoming(raw, now: rebuildTime), rules: rules)
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
        agenda = Agenda(items: items, horizon: horizon)
        onRebuild(agenda, rebuildTime)
    }

    /// Completes a reminder, removing its row first and restoring it on failure.
    public func complete(_ item: AgendaItem) async {
        guard let member = item.members.first else {
            return
        }

        let previous = agenda
        agenda.items.removeAll { $0.id == item.id }
        do {
            try await source.complete(reminder: member)
            errorMessage = nil
            requestRefresh()
        } catch {
            agenda = previous
            errorMessage = error.localizedDescription
        }
    }

    /// Opens a call link through the link opener.
    public func join(_ link: JoinLink) {
        opener.open(link)
    }

    /// Asks the loop for a rebuild.
    public func requestRefresh() {
        refresh.yield()
    }

    // MARK: Private

    private static let horizonDays = 2
    private static let secondsPerDay: TimeInterval = 86_400

    @ObservationIgnored private let source: any CalendarSource
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let opener: any LinkOpener
    @ObservationIgnored private let wake: AsyncStream<Void>
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let refreshRequests: AsyncStream<Void>
    @ObservationIgnored private let refresh: AsyncStream<Void>.Continuation

    private func horizon(around now: Date) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: Self.horizonDays, to: start)
            ?? start.addingTimeInterval(TimeInterval(Self.horizonDays) * Self.secondsPerDay)
        return DateInterval(start: start, end: end)
    }
}
