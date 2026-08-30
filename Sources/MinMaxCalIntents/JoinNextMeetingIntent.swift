import AppIntents
import MinMaxCalFeatures

public struct JoinNextMeetingIntent: AppIntent {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public static let title: LocalizedStringResource = "Join Next Meeting"
    public static let description: IntentDescription = .init("Opens the next call link in the app the Join tab chose.")

    public func perform() async throws -> some IntentResult {
        let joined = await MainActor.run {
            guard let link = agenda.nextCall?.joinLink else {
                return false
            }

            agenda.join(link)
            return true
        }
        guard joined else {
            throw IntentError.noCall
        }

        return .result()
    }

    // MARK: Internal

    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var agenda: AgendaModel
}
