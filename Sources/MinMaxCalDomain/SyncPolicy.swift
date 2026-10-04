import Foundation

public struct SyncPolicy: Codable, Equatable, Identifiable, Sendable {
    // MARK: Lifecycle

    public init(
        id: UUID = UUID(),
        source: String = "",
        destination: String = "",
        isEnabled: Bool = false,
        content: Content = .busy,
        allDay: AllDay = .busy,
        onlyBusy: Bool = true,
    ) {
        self.id = id
        self.source = source
        self.destination = destination
        self.isEnabled = isEnabled
        self.content = content
        self.allDay = allDay
        self.onlyBusy = onlyBusy
    }

    // MARK: Public

    public enum Content: String, Codable, CaseIterable, Sendable {
        case busy
        case original
        case travel
    }

    public enum AllDay: String, Codable, CaseIterable, Sendable {
        case all
        case busy
        case exclude
    }

    public var id: UUID
    public var source: String
    public var destination: String
    public var isEnabled: Bool
    public var content: Content
    public var allDay: AllDay
    public var onlyBusy: Bool

    public func hasAvailableCalendars(in calendars: [CalendarList]) -> Bool {
        source != destination
            && calendars.contains { $0.identifier == source && $0.kind == .event }
            && calendars.contains { calendar in
                calendar.identifier == destination && calendar.kind == .event
                    && calendar.allowsChanges && calendar.supportsBusy
            }
    }
}
