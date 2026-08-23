import Foundation

/// The long form of a day for the agenda's section headers: `Monday 24th August 2026`.
enum DayHeading {
    static func text(for date: Date, calendar: Calendar) -> String {
        let ordinal = NumberFormatter()
        ordinal.numberStyle = .ordinal
        ordinal.locale = calendar.locale
        let day = ordinal.string(for: calendar.component(.day, from: date)) ?? ""
        let style = Date.FormatStyle(calendar: calendar)
        return [
            date.formatted(style.weekday(.wide)),
            day,
            date.formatted(style.month(.wide)),
            date.formatted(style.year()),
        ].joined(separator: " ")
    }
}
