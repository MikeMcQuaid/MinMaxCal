import AppIntents
import MinMaxCalFeatures

public struct CompleteNextReminderIntent: AppIntent {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public static let title: LocalizedStringResource = "Complete Next Reminder"
    public static let description: IntentDescription = .init(
        "Ticks the first reminder still to do, the overdue one when there is one."
    )

    public func perform() async throws -> some IntentResult {
        let reminder = await MainActor.run { agenda.nextReminder }
        guard let reminder else {
            throw IntentError.noReminder
        }

        await agenda.complete(reminder)
        let message = await MainActor.run { agenda.errorMessage }
        if let message {
            throw IntentError.failed(message)
        }

        return .result()
    }

    // MARK: Internal

    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var agenda: AgendaModel
}
