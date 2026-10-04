public extension SyncWrite {
    /// Explains every changed field or the reason for creating or removing a copy.
    var reasons: [String] {
        switch self {
        case let .remove(_, _, reason):
            return [reason]

        case let .save(_, _, target, content):
            guard let target else {
                return ["The original matches this pair’s rules and has no matching copy."]
            }

            var changes = content.differences(from: target.content)
            if action == .adopt {
                changes.insert(
                    """
                    This existing copy uniquely matches the original. \
                    MinMaxCal will maintain it after switching to Sync.
                    """,
                    at: 0,
                )
            }
            if target.hasAlarms {
                changes.append("Remove the copy’s alarms to avoid duplicate notifications.")
            }
            return changes
        }
    }
}
