public struct Selection: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(calendarIdentifiers: Set<String>, reminderListIdentifiers: Set<String>) {
        self.calendarIdentifiers = calendarIdentifiers
        self.reminderListIdentifiers = reminderListIdentifiers
    }

    // MARK: Public

    public static let empty: Self = .init(calendarIdentifiers: [], reminderListIdentifiers: [])

    public var calendarIdentifiers: Set<String>
    public var reminderListIdentifiers: Set<String>

    public var isEmpty: Bool {
        calendarIdentifiers.isEmpty && reminderListIdentifiers.isEmpty
    }

    public func contains(_ list: CalendarList) -> Bool {
        identifiers(for: list.kind).contains(list.identifier)
    }

    public mutating func set(_ list: CalendarList, selected: Bool) {
        switch (list.kind, selected) {
        case (.event, true):
            calendarIdentifiers.insert(list.identifier)

        case (.event, false):
            calendarIdentifiers.remove(list.identifier)

        case (.reminder, true):
            reminderListIdentifiers.insert(list.identifier)

        case (.reminder, false):
            reminderListIdentifiers.remove(list.identifier)
        }
    }

    // MARK: Private

    private func identifiers(for kind: ListKind) -> Set<String> {
        switch kind {
        case .event:
            calendarIdentifiers

        case .reminder:
            reminderListIdentifiers
        }
    }
}
