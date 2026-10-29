import Foundation
import MinMaxCalCoachingDomain
import Observation

/// Owns an explicit recording session, its local transcript and saved summaries.
@Observable
public final class MeetingModel {
    // MARK: Lifecycle

    /// Creates a meeting model with injected capture, storage and setup ports.
    public init(
        recorder: any MeetingRecorder,
        store: any MeetingStore,
        speechModels: any SpeechModelStore,
        calendar: any MeetingCalendar? = nil,
        defaults: UserDefaults? = nil,
        notifier: any MeetingNotifier? = nil,
    ) {
        self.recorder = recorder
        self.store = store
        self.speechModels = speechModels
        self.calendar = calendar
        self.defaults = defaults
        self.notifier = notifier
        meetingRetention = (defaults?.object(forKey: "coaching.transcriptRetentionHours") as? Int)
            .flatMap(MeetingRetention.init(rawValue:)) ?? .twoDays
        calendarPromptsEnabled = defaults?.object(forKey: "coaching.calendarPromptsEnabled") as? Bool ?? true
        myName = defaults?.string(forKey: "coaching.myName") ?? ""
        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
        targetShare = defaults?.object(forKey: "coaching.targetShare") as? Double ?? 0.4
        // swiftlint:disable:next no_magic_numbers - Panel sizing and targets.
        turnLimit = defaults?.object(forKey: "coaching.turnLimit") as? Double ?? 60
    }

    // MARK: Public

    /// The capture lifecycle, independent of popover visibility.
    public enum Phase {
        /// No capture is running.
        case idle
        /// Local models and audio capture are starting after an explicit choice.
        case preparing
        /// Audio is being analysed and checkpointed.
        case recording
        /// Capture is draining and the summary is being saved.
        case stopping
    }

    /// Speech-model setup status; only ready models may record.
    public enum ModelState {
        /// Saved models are being checked locally.
        case checking
        /// Explicit download or setup is needed before recording.
        case missing
        /// An explicitly requested model download is running.
        case downloading
        /// All required models have been checked locally.
        case ready
    }

    /// The current capture lifecycle state.
    public internal(set) var phase: Phase = .idle
    /// The current explicit speech-model setup state.
    public internal(set) var modelState: ModelState = .checking
    /// The latest recording, setup or history failure for inline display.
    public var error: String?

    /// Inferred meetings projected from the existing agenda.
    public internal(set) var calendarMeetings: [CalendarMeeting] = []

    // MARK: Package

    package internal(set) var notificationMessage: String?
    package var calendarNow: Date = .now
    package var reduceSpeakerEcho = true
    package internal(set) var meetings: [Meeting] = []
    package internal(set) var current: Meeting?
    package internal(set) var downloadStatus = ""
    package internal(set) var calendarMessage: String?
    package internal(set) var hasCalendarAccess = false
    package internal(set) var isReadingCalendar = false
    package internal(set) var microphoneLevel: Float = 0
    package internal(set) var meetingLevel: Float = 0
    package internal(set) var activeSpeakerIDs: [String] = []
    package internal(set) var hasMeetingAudio = false
    package var selectedID: UUID?

    package var displayedError: String? {
        if error == selected?.notice {
            nil
        } else {
            error
        }
    }

    package var recordingTimeRemaining: TimeInterval? {
        guard phase == .recording, let current else {
            return nil
        }

        return RecordingSession.timeRemaining(at: current.duration)
    }

    package var title = "" {
        didSet {
            if title != oldValue {
                otherParticipantOverride = nil
            }
        }
    }

    package var myName: String {
        didSet { defaults?.set(myName, forKey: "coaching.myName") }
    }

    package var targetShare: Double {
        didSet { defaults?.set(targetShare, forKey: "coaching.targetShare") }
    }

    package var turnLimit: Double {
        didSet { defaults?.set(turnLimit, forKey: "coaching.turnLimit") }
    }

    package var meetingRetention: MeetingRetention {
        didSet {
            defaults?.set(meetingRetention.rawValue, forKey: "coaching.transcriptRetentionHours")
            retentionTask?.cancel()
            retentionTask = Task {
                await refreshHistory()
            }
        }
    }

    package var calendarPromptsEnabled: Bool {
        didSet {
            defaults?.set(calendarPromptsEnabled, forKey: "coaching.calendarPromptsEnabled")
            Task {
                await updateCalendarPrompts()
            }
        }
    }

    package internal(set) var calendarMeetingID: String? {
        didSet {
            if calendarMeetingID != oldValue {
                otherParticipantOverride = nil
            }
        }
    }

    package var canStart: Bool {
        isEnabled && phase == .idle && recordingTask == nil && modelState == .ready && isReadingCalendar == false
    }

    package var calendarMeeting: CalendarMeeting? {
        calendarMeetings.first { $0.id == calendarMeetingID }
    }

    package var otherParticipantName: String {
        get {
            otherParticipantOverride ?? ParticipantNames.otherPerson(
                title: title,
                myName: myName,
                invitees: calendarMeeting?.participantNames ?? [],
            ) ?? ""
        }
        set { otherParticipantOverride = newValue }
    }

    package var selected: Meeting? {
        if selectedID == current?.id {
            return current
        }
        return meetings.first { $0.id == selectedID }
    }

    package var history: [Meeting] {
        var saved = meetings.filter { $0.id != current?.id }
        if phase == .idle, let current {
            saved.insert(current, at: 0)
        }
        return saved
    }

    package var speakerStatus: String {
        guard let current, activeSpeakerIDs.isEmpty == false else {
            return "Listening…"
        }

        return "Speaking now: " + activeSpeakerIDs.map { current.name(for: $0) }.joined(separator: ", ")
    }

    package func selectCalendarMeeting(_ id: String?) {
        calendarChoiceIsManual = true
        calendarMeetingID = id
        applyCalendarTitle()
    }

    package func rename(
        speakerID: String,
        to newName: String,
        meetingID: UUID,
    ) async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            return
        }

        if current?.id == meetingID {
            current?.names[speakerID] = name
            if let current {
                await saveEdited(current)
            }
        } else if var meeting = meetings.first(where: { $0.id == meetingID }) {
            meeting.names[speakerID] = name
            await saveEdited(meeting)
        }
    }

    package func delete(_ meeting: Meeting) async {
        guard phase == .idle || meeting.id != current?.id else {
            return
        }

        do {
            try await store.delete(id: meeting.id)
            meetings.removeAll { $0.id == meeting.id }
            if current?.id == meeting.id {
                current = nil
            }
            if selectedID == meeting.id {
                selectedID = nil
            }
            if error == meeting.notice {
                error = nil
            }
            await refreshHistory()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Internal

    var isEnabled = true

    let recorder: any MeetingRecorder
    let store: any MeetingStore
    let speechModels: any SpeechModelStore
    let calendar: any MeetingCalendar?
    let defaults: UserDefaults?
    let notifier: any MeetingNotifier?
    var notificationsAllowed = false
    var otherParticipantOverride: String?
    var suggestedTitle: String?
    var calendarChoiceIsManual = false
    var recordingTask: Task<Void, Never>?
    var downloadTask: Task<Void, Never>?
    var retentionTask: Task<Void, Never>?

    func saveEdited(_ meeting: Meeting) async {
        do {
            try await store.save(meeting)
            await refreshHistory()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
