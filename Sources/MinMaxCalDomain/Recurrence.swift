public struct Recurrence: Hashable, Sendable {
    // MARK: Lifecycle

    public init(frequency: Frequency, interval: Int) {
        self.frequency = frequency
        self.interval = interval
    }

    // MARK: Public

    public enum Frequency: Hashable, Sendable {
        case daily
        case monthly
        case weekly
        case yearly
    }

    public var frequency: Frequency
    public var interval: Int

    /// `Every week`, `Every 2 weeks`.
    public var description: String {
        let unit =
            switch frequency {
            case .daily:
                "day"

            case .weekly:
                "week"

            case .monthly:
                "month"

            case .yearly:
                "year"
            }
        return interval > 1 ? "Every \(String(interval)) \(unit)s" : "Every \(unit)"
    }
}
