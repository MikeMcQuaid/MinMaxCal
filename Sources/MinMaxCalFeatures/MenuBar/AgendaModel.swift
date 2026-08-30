import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Observation

/// Owns the agenda and rebuilds it on every change, minute, system change or setting.
@Observable
public final class AgendaModel {
    // MARK: Lifecycle

    /// Wires the ports; `systemChanges`, `clock` and `calendar` are injectable for tests.
    @preconcurrency
    public init(
        source: any CalendarSource,
        settings: SettingsStore,
        opener: any LinkOpener,
        systemChanges: AsyncStream<Void> = AsyncStream { $0.finish() },
        clock: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current,
    ) {
        self.source = source
        self.settings = settings
        self.opener = opener
        self.systemChanges = systemChanges
        self.clock = clock
        self.calendar = calendar
        now = clock()
        titleLimit = settings.titleLimit
        rules = settings.matchingRules
        (refreshRequests, refresh) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    // MARK: Public

    /// The current agenda: today and tomorrow, filtered, merged and sorted.
    public private(set) var agenda: Agenda = .empty
    /// The clock reading of the last rebuild.
    public private(set) var now: Date
    /// The grants the app was given at launch.
    public private(set) var access: AccessStatus = .notDetermined
    /// The matching rules of the last rebuild, for the views that tidy what they show.
    public private(set) var rules: MatchingRules
    /// The menu bar title length from Settings.
    public private(set) var titleLimit: Int
    /// Whether any calendar or list is selected, for the empty state.
    public private(set) var hasSelection = false
    /// Why the last completion failed.
    public private(set) var errorMessage: String?
    /// Called with every new agenda; the app points this at the takeover scheduler.
    public var onRebuild: (Agenda, Date) -> Void = { _, _ in }
    /// Shows an item as a takeover preview; the app points this at `TakeoverModel.preview`.
    public var preview: (AgendaItem) -> Void = { _ in }

    /// The menu bar title, or nil for the icon alone.
    public var title: String? {
        MenuBarTitle.render(agenda: agenda, now: now, limit: titleLimit)
    }

    /// The item the menu bar shows.
    public var nextItem: AgendaItem? {
        MenuBarTitle.nextItem(in: agenda, now: now)
    }

    /// The next item with a call link that has not ended.
    public var nextCall: AgendaItem? {
        agenda.items.first { $0.joinLink != nil && $0.isCompleted == false && $0.hasEnded(at: now) == false }
    }

    /// The first reminder still to do, the overdue one when there is one.
    public var nextReminder: AgendaItem? {
        agenda.items.first { $0.kind == .reminder && $0.isCompleted == false }
    }

    /// Requests access, then rebuilds for as long as the task lives. Triggers that arrive during a
    /// rebuild collapse into one more, so a burst of sync notifications costs two fetches, not a queue.
    public func run() async {
        access = await source.requestAccess()
        await rebuild()
        let (triggers, trigger) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let feeds = [source.changes, MinuteTicks.stream(clock: clock), systemChanges, settings.changes, refreshRequests]
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
        publish(\.titleLimit, settings.titleLimit)
        let selection = settings.selection
        publish(\.rules, settings.matchingRules)
        publish(\.hasSelection, selection.isEmpty == false)
        let horizon = horizon(around: rebuildTime)
        let raw = await source.agenda(from: horizon.start, to: horizon.end, selection: selection)
        let merged = AgendaMerger.merge(AgendaFilter.upcoming(raw, now: rebuildTime), rules: rules)
        recentlyCompleted.removeAll { rebuildTime.timeIntervalSince($0.at) > Self.undoWindow }
        let undoable = recentlyCompleted.map(\.item)
            .filter { completed in merged.contains { $0.id == completed.id } == false }
        let items = (AgendaFilter.named(merged, rules: rules) + undoable)
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
        publish(\.agenda, Agenda(items: items, horizon: horizon))
        onRebuild(agenda, rebuildTime)
    }

    /// Completes a reminder. Its row stays, struck through, for a few minutes so the tick can be
    /// undone; a failed save restores the row with the error.
    public func complete(_ item: AgendaItem) async {
        await setCompleted(true, item)
    }

    /// Reverses a recent completion in Reminders.
    public func uncomplete(_ item: AgendaItem) async {
        await setCompleted(false, item)
    }

    /// Opens a call link in the app Settings chose for its service.
    public func join(_ link: JoinLink) {
        opener.open(link, in: settings.join[link.service])
    }

    /// Asks the loop for a rebuild.
    public func requestRefresh() {
        refresh.yield()
    }

    // MARK: Private

    private static let horizonDays = 2
    private static let secondsPerDay: TimeInterval = 86_400
    private static let undoWindow: TimeInterval = 300

    @ObservationIgnored private let source: any CalendarSource
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let opener: any LinkOpener
    @ObservationIgnored private let systemChanges: AsyncStream<Void>
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let refreshRequests: AsyncStream<Void>
    @ObservationIgnored private let refresh: AsyncStream<Void>.Continuation
    @ObservationIgnored private var recentlyCompleted: [(item: AgendaItem, at: Date)] = []

    private func setCompleted(_ completed: Bool, _ item: AgendaItem) async {
        guard let member = item.members.first, let index = agenda.items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let previous = agenda
        var changed = item
        changed.isCompleted = completed
        agenda.items[index] = changed
        recentlyCompleted.removeAll { $0.item.id == item.id }
        if completed {
            recentlyCompleted.append((item: changed, at: clock()))
        }
        do {
            try await source.setCompleted(completed, reminder: member)
            errorMessage = nil
            requestRefresh()
        } catch {
            agenda = previous
            recentlyCompleted.removeAll { $0.item.id == item.id }
            errorMessage = error.localizedDescription
        }
    }

    /// Assigns only what differs, so an idle minute re-renders nothing but the countdown.
    private func publish<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<AgendaModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func horizon(around now: Date) -> DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: Self.horizonDays, to: start)
            ?? start.addingTimeInterval(TimeInterval(Self.horizonDays) * Self.secondsPerDay)
        return DateInterval(start: start, end: end)
    }
}
