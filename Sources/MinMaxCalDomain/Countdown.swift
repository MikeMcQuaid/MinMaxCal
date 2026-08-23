import Foundation

/// Formats the time until something as the two largest units that apply.
public enum Countdown {
    // MARK: Public

    /// `2d3h`, `1h52`, `45m`, `<1m` or `now` for the interval from `now` to `target`; minutes
    /// after hours read like a clock, so they carry no unit.
    public static func format(from now: Date, to target: Date) -> String {
        let seconds = target.timeIntervalSince(now)
        guard seconds > 0 else {
            return "now"
        }

        let minutes = Int(seconds / TimeInterval(minutesPerHour))
        guard minutes >= 1 else {
            return "<1m"
        }

        let days = minutes / minutesPerDay
        let hours = minutes % minutesPerDay / minutesPerHour
        let remainder = minutes % minutesPerHour
        if days > 0 {
            return hours > 0 ? "\(days)d\(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return remainder > 0 ? "\(hours)h\(remainder)" : "\(hours)h"
        }
        return "\(remainder)m"
    }

    /// The countdown to the item's start, then to its end, then `now`.
    public static func text(for item: AgendaItem, now: Date) -> String {
        if item.hasStarted(at: now) == false {
            return format(from: now, to: item.start)
        }
        guard let end = item.end else {
            return "now"
        }

        return format(from: now, to: end)
    }

    // MARK: Private

    private static let minutesPerHour = 60
    private static let hoursPerDay = 24
    private static let minutesPerDay = hoursPerDay * minutesPerHour
}
