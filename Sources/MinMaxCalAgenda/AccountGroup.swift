import MinMaxCalDomain

public struct AccountGroup: Hashable, Identifiable, Sendable {
    public var account: String
    public var lists: [CalendarList]

    public var id: String {
        account
    }

    public static func grouping(_ lists: [CalendarList]) -> [Self] {
        var groups = [Self]()
        for list in lists {
            if let index = groups.firstIndex(where: { $0.account == list.accountName }) {
                groups[index].lists.append(list)
            } else {
                groups.append(Self(account: list.accountName, lists: [list]))
            }
        }
        return groups
    }
}
