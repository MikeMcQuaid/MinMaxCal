import AppIntents
import MinMaxCalFeatures

public struct PreviewTakeoverIntent: AppIntent {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public static let title: LocalizedStringResource = "Preview Takeover"
    public static let description: IntentDescription =
        .init("Shows the next item as a takeover without recording anything.")

    public func perform() async throws -> some IntentResult {
        let previewed = await MainActor.run {
            guard let item = agenda.nextItem else {
                return false
            }

            takeover.preview(item)
            return true
        }
        guard previewed else {
            throw IntentError.nothingUpcoming
        }

        return .result()
    }

    // MARK: Internal

    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var agenda: AgendaModel
    @Dependency var takeover: TakeoverModel
}
