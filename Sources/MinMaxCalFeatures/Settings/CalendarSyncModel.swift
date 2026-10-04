import Foundation
import MinMaxCalData
import MinMaxCalDomain
import Observation

/// Compares and maintains calendar copies while the app is running.
@Observable
public final class CalendarSyncModel {
    // MARK: Lifecycle

    /// Injects calendar access, settings and the durable ownership ledger.
    @preconcurrency
    public init(
        source: any CalendarSyncSource,
        settings: SettingsStore,
        ledger: SyncLedgerStore = SyncLedgerStore(),
        clock: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current,
    ) {
        self.source = source
        self.settings = settings
        self.ledger = ledger
        self.clock = clock
        self.calendar = calendar
        configuration = settings.sync
        do { links = try ledger.load() } catch { errorMessage = error.localizedDescription }
    }

    // MARK: Public

    /// Known original/copy relationships, including pending creations.
    public private(set) var links: [SyncLink] = []
    /// Proposed changes and conflicts from the latest snapshot.
    public private(set) var report: SyncPlan = .init()
    /// The start of the most recent successful check.
    public private(set) var lastChecked: Date?
    /// Local validation results for the current comparison, never evidence of a saved event.
    public private(set) var rehearsal: (checked: Int, failures: [UUID: String])?
    /// Why the last check or mutation failed.
    public private(set) var errorMessage: String?
    /// Whether a check or cleanup is already in progress.
    public private(set) var isRunning = false
    /// Requests an agenda rebuild when copy identities change.
    public var onMappingChange: () -> Void = {}

    /// The persisted mode and calendar pairs.
    public var configuration: SyncSettings {
        didSet {
            settings.sync = configuration
            report = SyncPlan()
            diagnosticSnapshot = nil
            lastChecked = nil
            rehearsal = nil
            errorMessage = nil
            requestRefresh()
        }
    }

    /// Coalesces requests without delaying the agenda.
    public func requestRefresh() {
        guard configuration.mode != .off else {
            return
        }

        if isRunning {
            refreshPending = true
            return
        }
        Task { await self.refresh() }
    }

    /// Checks once, with at most one pending follow-up at a time.
    public func refresh(rehearsing: Bool = false) async {
        guard rehearsing == false || configuration.mode == .compare else {
            return
        }
        guard isRunning == false else {
            refreshPending = true
            return
        }

        isRunning = true
        defer { isRunning = false }
        repeat {
            refreshPending = false
            do {
                try await reconcile(rehearsing: rehearsing)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                refreshPending = false
            }
        } while refreshPending && Task.isCancelled == false
    }

    /// Fetches the exact owned copies to review before confirming removal.
    public func removalPreview(for policy: UUID) async throws -> [SyncWrite] {
        guard isRunning == false, configuration.mode == .sync else {
            throw SyncError.changed
        }

        isRunning = true
        defer { isRunning = false }
        let interval = try horizon()
        let snapshot = try await source.syncSnapshot(
            policies: configuration.policies, links: links, interval: interval,
        )
        return try links.filter { $0.policy == policy && $0.isManaged }.compactMap { link in
            guard snapshot.calendars.contains(where: { $0.identifier == link.destination && $0.allowsChanges }) else {
                throw SyncError.calendar
            }

            let copies = snapshot.events.filter { event in
                event.identity.calendar == link.destination
                    && (link.copy?.matches(event.identity) == true
                        || SyncMarker.identifier(in: event.content.notes) == link.id)
            }
            guard copies.count <= 1 else {
                throw SyncError.ownership
            }
            guard let copy = copies.first, copy.content.start < interval.end, copy.content.end > interval.start else {
                return nil
            }
            guard copy.isOwned(by: link) else {
                throw SyncError.ownership
            }

            return .remove(link, target: copy, reason: "You chose Remove Copies.")
        }
    }

    /// Disables a pair and removes only the copies shown in its confirmation.
    public func removeCopies(_ writes: [SyncWrite], for policy: UUID) async {
        guard isRunning == false, configuration.mode == .sync,
              let index = configuration.policies.firstIndex(where: { $0.id == policy })
        else {
            return
        }

        isRunning = true
        defer {
            isRunning = false
            if errorMessage == nil {
                requestRefresh()
            }
        }
        configuration.policies[index].isEnabled = false
        let expectedConfiguration = configuration
        do {
            for write in writes {
                guard configuration == expectedConfiguration, write.action == .remove,
                      write.link.policy == policy, write.link.isManaged, links.contains(write.link)
                else {
                    throw SyncError.changed
                }

                _ = try await source.applySync(write)
                try persist(links.filter { $0.id != write.link.id })
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes an explicitly reviewed, unlinked legacy Calendar Sync copy.
    public func removeLegacy(_ event: SyncEvent) async {
        guard isRunning == false, configuration.mode == .sync,
              report.unresolved.contains(event), SyncMarker.isLegacy(event.content.notes)
        else {
            return
        }

        isRunning = true
        defer { isRunning = false }
        do {
            try await source.removeLegacyCopy(event, interval: horizon())
            report.unresolved.removeAll { $0.identity == event.identity }
            errorMessage = nil
            onMappingChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Internal

    @ObservationIgnored let source: any CalendarSyncSource
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let ledger: SyncLedgerStore
    @ObservationIgnored let clock: @Sendable () -> Date
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored var refreshPending = false
    @ObservationIgnored var diagnosticSnapshot: SyncDiagnosticSnapshot?

    // MARK: Private

    private func reconcile(rehearsing: Bool) async throws {
        let expectedConfiguration = configuration
        guard expectedConfiguration.mode != .off,
              rehearsing == false || expectedConfiguration.mode == .compare,
              expectedConfiguration.policies.contains(where: \.isEnabled)
        else {
            return
        }

        let saved = try ledger.load()
        let interval = try horizon()
        let snapshot = try await source.syncSnapshot(
            policies: expectedConfiguration.policies,
            links: saved,
            interval: interval,
        )
        guard configuration == expectedConfiguration else {
            refreshPending = true
            return
        }

        let plan = SyncPlanner(
            events: snapshot.events,
            calendars: snapshot.calendars,
            policies: expectedConfiguration.policies,
            links: saved,
            interval: interval,
        ).plan()
        diagnosticSnapshot = SyncDiagnosticSnapshot(
            interval: interval, calendars: snapshot.calendars, events: snapshot.events, inputLinks: saved, plan: plan,
        )
        try persist(plan.links)
        report = plan
        lastChecked = interval.start
        rehearsal = nil
        if rehearsing {
            let result = await rehearse(plan, configuration: expectedConfiguration)
            guard configuration == expectedConfiguration, Task.isCancelled == false else {
                return
            }

            rehearsal = result
            return
        }
        guard expectedConfiguration.mode == .sync else {
            return
        }

        for write in plan.writes {
            guard configuration == expectedConfiguration, Task.isCancelled == false else {
                return
            }

            try await perform(write)
            await Task.yield()
        }
    }

    private func perform(_ write: SyncWrite) async throws {
        var updated = links
        guard let index = updated.firstIndex(where: { $0.id == write.link.id }) else {
            throw SyncError.ownership
        }

        updated[index].isManaged = true
        try persist(updated)
        let identity = try await source.applySync(write)
        switch write {
        case .save:
            updated[index].copy = identity

        case .remove:
            updated.remove(at: index)
        }
        try persist(updated)
    }

    private func persist(_ updated: [SyncLink]) throws {
        try ledger.save(updated)
        if links != updated {
            links = updated
            onMappingChange()
        }
    }

    private func horizon() throws -> DateInterval {
        let start = clock()
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            throw SyncError.changed
        }

        return DateInterval(start: start, end: end)
    }
}
