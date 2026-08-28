import Foundation

/// The long form of a day for the agenda's section headers: `Monday 24th August 2026`.
enum DayHeading {
    // MARK: Internal

    static func text(for date: Date, calendar: Calendar) -> String {
        if ordinal.locale != calendar.locale {
            ordinal.locale = calendar.locale
        }
        let day = ordinal.string(for: calendar.component(.day, from: date)) ?? ""
        let style = Date.FormatStyle(calendar: calendar)
        return [
            date.formatted(style.weekday(.wide)),
            day,
            date.formatted(style.month(.wide)),
            date.formatted(style.year()),
        ].joined(separator: " ")
    }

    // MARK: Private

    /// A formatter is costly to create and this one is asked for on every agenda render.
    private static let ordinal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()
}
