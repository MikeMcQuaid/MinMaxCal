import MinMaxCalDomain

extension Fixtures {
    static let syncPolicy: SyncPolicy = .init(source: "home", destination: "work", isEnabled: true)

    static var syncCalendars: [CalendarList] {
        ["home", "work"].map { identifier in
            CalendarList(
                identifier: identifier,
                title: identifier,
                colour: .grey,
                kind: .event,
                accountName: "Account",
                allowsChanges: true,
                supportsBusy: true,
            )
        }
    }

    static var syncOriginal: SyncEvent {
        SyncEvent(
            identity: SyncIdentity(calendar: "home", item: "original", event: "original"),
            content: SyncContent(
                title: "Meeting",
                start: now.addingTimeInterval(600),
                end: now.addingTimeInterval(1_800),
            ),
        )
    }
}
