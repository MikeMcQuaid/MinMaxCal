import AppIntents
import MinMaxCalFeatures

/// Resolves entities against the current agenda.
public struct AgendaItemQuery: EntityQuery {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public func entities(for identifiers: [String]) async -> [AgendaItemEntity] {
        await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async -> [AgendaItemEntity] {
        await MainActor.run { agenda.agenda.items.map { AgendaItemEntity($0, now: agenda.now) } }
    }

    // MARK: Internal

    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var agenda: AgendaModel
}
