import Foundation
import MinMaxCalCoachingDomain
import MinMaxCalDomain
import Observation

/// Creates and releases coaching services only while the feature is enabled.
@Observable
public final class CoachingController {
    // MARK: Lifecycle

    /// Creates a lazy feature boundary with injected services.
    @preconcurrency
    public init(
        defaults: UserDefaults = .standard,
        makeModel: @escaping () -> MeetingModel,
    ) {
        self.defaults = defaults
        self.makeModel = makeModel
        enabled = defaults.bool(forKey: "coaching.enabled")
        recordOnJoin = defaults.object(forKey: "coaching.recordOnJoin") as? Bool ?? true
        if enabled {
            activate()
        }
    }

    // MARK: Public

    /// Whether the user has enabled coaching on this Mac.
    public private(set) var enabled: Bool
    /// The active feature, absent while disabled.
    public private(set) var model: MeetingModel?
    /// Whether capture is being stopped or the feature enabled.
    public private(set) var isChanging = false
    /// Whether the agenda panel is showing coaching inline.
    public var showingMeeting = false

    /// The default for explicit Join actions; it never starts recording by itself.
    public var recordOnJoin: Bool {
        didSet { defaults.set(recordOnJoin, forKey: "coaching.recordOnJoin") }
    }

    /// Whether Join actions advertise recording in the opted-in feature.
    public var recordsJoins: Bool {
        enabled && recordOnJoin
    }

    /// Whether the selected Join action is ready, including an existing recording.
    public var canJoin: Bool {
        recordsJoins == false || canRecord || model?.phase == .recording
    }

    /// Whether setup is ready for an explicit recording choice.
    public var canRecord: Bool {
        enabled && isChanging == false && model?.canStart == true
    }

    /// Replaces only the menu bar icon during recording, keeping the calendar title unchanged.
    public var symbol: String? {
        guard enabled, let model, model.phase == .recording, let meeting = model.current else {
            return nil
        }

        return ConversationBalance(meeting: meeting, targetShare: model.targetShare, turnLimit: model.turnLimit)
            .needsRoom ? "ear.badge.waveform" : "waveform"
    }

    /// Opens a call and records only after an explicit Join with that default enabled.
    public func join(
        _ item: AgendaItem,
        using open: (JoinLink) -> Void,
        refresh: () async -> Void,
    ) async {
        guard let link = item.joinLink, canJoin else {
            return
        }

        let shouldRecord = recordsJoins && model?.phase == .idle
        open(link)
        if shouldRecord {
            await refresh()
            await record(item)
        }
    }

    /// Revalidates a takeover's event after an explicit Join and Record choice.
    public func record(_ item: AgendaItem) async {
        guard enabled, let model, let id = AgendaMeetingCalendar.id(for: item) else {
            return
        }

        await waitForAgenda()
        guard enabled, self.model === model else {
            return
        }

        showingMeeting = true
        _ = await model.recordCalendarMeeting(id, fromPrompt: false)
    }

    /// Persists opt-in and drains recording before releasing disabled services.
    public func setEnabled(_ value: Bool) async {
        guard value != enabled,
              isChanging == false
        else {
            return
        }

        isChanging = true
        defer { isChanging = false }
        enabled = value
        defaults.set(value, forKey: "coaching.enabled")
        if value {
            activate()
        } else {
            startup?.cancel()
            refresh?.cancel()
            await model?.deactivate()
            await startup?.value
            await refresh?.value
            model = nil
            showingMeeting = false
        }
    }

    /// Reconciles meeting suggestions after the existing agenda rebuild.
    public func agendaChanged(at date: Date) {
        guard enabled,
              let model
        else {
            return
        }

        let previous = refresh
        refresh?.cancel()
        refresh = Task {
            await startup?.value
            await previous?.value
            guard Task.isCancelled == false else {
                return
            }

            await model.refreshCalendar(at: date)
        }
    }

    /// Waits for the shared agenda projection before revalidating a notification response.
    public func waitForAgenda() async {
        await startup?.value
        await refresh?.value
    }

    /// Updates the in-memory clock without fetching or scheduling work.
    public func tick(at date: Date) {
        model?.calendarNow = date
    }

    // MARK: Private

    private let defaults: UserDefaults
    private let makeModel: () -> MeetingModel
    private var startup: Task<Void, Never>?
    private var refresh: Task<Void, Never>?

    private func activate() {
        let meetingModel = makeModel()
        model = meetingModel
        startup = Task {
            await meetingModel.load()
        }
    }
}
