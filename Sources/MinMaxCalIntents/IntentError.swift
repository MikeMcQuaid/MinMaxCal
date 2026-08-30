import AppIntents

/// Why an intent had nothing to act on, in Shortcuts' own words.
enum IntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case failed(String)
    case noCall
    case noReminder
    case noReminderTakeover
    case nothingUpcoming

    // MARK: Internal

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case let .failed(message):
            "\(message)"

        case .noCall:
            "No meeting with a call link is coming up today or tomorrow."

        case .noReminder:
            "No reminder is left to complete today or tomorrow."

        case .noReminderTakeover:
            "No reminder takeover is on screen to snooze."

        case .nothingUpcoming:
            "Nothing is coming up today or tomorrow."
        }
    }
}
