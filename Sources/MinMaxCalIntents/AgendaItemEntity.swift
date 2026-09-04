import AppIntents
import Foundation
import MinMaxCalDomain

/// An agenda item as Shortcuts sees it: what the menu bar and the join button use, and nothing
/// else the invitation wrote.
public struct AgendaItemEntity: AppEntity {
    // MARK: Lifecycle

    init(_ item: AgendaItem, now: Date) {
        id = item.members
            .lazy
            .map { member in
                [member.calendarItemIdentifier, member.occurrenceDate.map { String($0.timeIntervalSinceReferenceDate) }]
                    .compactMap(\.self)
                    .joined(separator: "@")
            }
            .joined(separator: "+")
        title = item.displayTitle
        kind = item.kind == .reminder ? "Reminder" : "Event"
        start = item.start
        end = item.end
        countdown = Countdown.text(for: item, now: now)
        joinURL = item.joinLink?.url
    }

    // MARK: Public

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Agenda Item"
    public static let defaultQuery: AgendaItemQuery = .init()

    public var id: String

    @Property(title: "Title")
    public var title: String
    @Property(title: "Kind")
    public var kind: String
    @Property(title: "Start")
    public var start: Date
    @Property(title: "End")
    public var end: Date?
    @Property(title: "Countdown")
    public var countdown: String
    @Property(title: "Join Link")
    public var joinURL: URL?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(countdown)")
    }
}
