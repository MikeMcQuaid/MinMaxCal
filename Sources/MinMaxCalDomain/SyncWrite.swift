/// A proposed mutation of an owned calendar copy.
public enum SyncWrite: Sendable {
    case remove(SyncLink, target: SyncEvent, reason: String)
    case save(SyncLink, source: SyncEvent, target: SyncEvent?, content: SyncContent)

    // MARK: Public

    public enum Action: String, CaseIterable, Sendable {
        case adopt = "Keep the existing copy"
        case create = "Create a new copy"
        case remove = "Remove the copy"
        case update = "Update the existing copy"
    }

    public var action: Action {
        switch self {
        case let .save(_, _, target, _):
            guard let target else {
                return .create
            }

            return SyncMarker.isLegacy(target.content.notes) ? .adopt : .update

        case .remove:
            return .remove
        }
    }

    /// Ownership to persist before attempting the mutation.
    public var link: SyncLink {
        switch self {
        case let .remove(link, _, _),
             let .save(link, _, _, _):
            link
        }
    }
}
