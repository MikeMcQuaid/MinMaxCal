import AppIntents
import MinMaxCalFeatures

public struct SnoozeTakeoverIntent: AppIntent {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public static let title: LocalizedStringResource = "Snooze Takeover"
    public static let description: IntentDescription = .init(
        "Snoozes the reminder takeover on screen for one of the configured durations."
    )

    @Parameter(title: "Minutes", optionsProvider: SnoozeMinutesOptions())
    public var minutes: Int

    public func perform() async throws -> some IntentResult {
        let snoozed = await MainActor.run {
            guard takeover.current?.reminders.isEmpty == false, takeover.snoozeMinutes.contains(minutes) else {
                return false
            }

            takeover.snooze(minutes: minutes)
            return true
        }
        guard snoozed else {
            throw IntentError.noReminderTakeover
        }

        return .result()
    }

    // MARK: Internal

    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var takeover: TakeoverModel
}
