import Foundation

public struct Takeover: Hashable, Sendable {
    // MARK: Lifecycle

    public init(entries: [Entry], moment: Date, isPreview: Bool = false) {
        self.entries = entries
        self.moment = moment
        self.isPreview = isPreview
    }

    // MARK: Public

    public struct Entry: Hashable, Identifiable, Sendable {
        // MARK: Lifecycle

        public init(item: AgendaItem, trigger: TakeoverTrigger) {
            self.item = item
            self.trigger = trigger
        }

        // MARK: Public

        public var item: AgendaItem
        public var trigger: TakeoverTrigger

        public var id: [MemberIdentity] {
            item.members
        }
    }

    public var entries: [Entry]
    public var moment: Date
    public var isPreview: Bool

    public var primary: Entry? {
        entries.first
    }

    public var reminders: [Entry] {
        entries.filter { $0.item.kind == .reminder }
    }
}
