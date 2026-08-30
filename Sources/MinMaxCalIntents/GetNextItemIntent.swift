import AppIntents
import MinMaxCalFeatures

public struct GetNextItemIntent: AppIntent {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public static let title: LocalizedStringResource = "Get Next Item"
    public static let description: IntentDescription = .init("The item the menu bar shows: the next event or reminder.")

    public func perform() async throws -> some IntentResult & ReturnsValue<AgendaItemEntity> {
        let entity = await MainActor.run { agenda.nextItem.map { AgendaItemEntity($0, now: agenda.now) } }
        guard let entity else {
            throw IntentError.nothingUpcoming
        }

        return .result(value: entity)
    }

    // MARK: Internal

    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var agenda: AgendaModel
}
