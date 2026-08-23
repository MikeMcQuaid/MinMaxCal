import Foundation

public struct Agenda: Hashable, Sendable {
    // MARK: Lifecycle

    public init(items: [AgendaItem], horizon: DateInterval) {
        self.items = items
        self.horizon = horizon
    }

    // MARK: Public

    public static let empty: Self = .init(items: [], horizon: DateInterval(start: .distantPast, end: .distantPast))

    public var items: [AgendaItem]
    public var horizon: DateInterval
}
