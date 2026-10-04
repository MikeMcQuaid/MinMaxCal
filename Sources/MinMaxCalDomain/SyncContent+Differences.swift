extension SyncContent {
    func differences(from current: Self) -> [String] {
        var reasons = [String]()
        if title != current.title {
            reasons.append("Title: ‘\(current.title)’ → ‘\(title)’, to match this pair’s settings.")
        }
        if start != current.start || end != current.end {
            reasons.append("The copy’s time differs from the original; use the original’s current time.")
        }
        if isAllDay != current.isAllDay {
            reasons.append("Change the all-day setting to match the original.")
        }
        if availability != current.availability {
            reasons
                .append(
                    "Availability: \(current.availability.rawValue) → \(availability.rawValue), to match the original."
                )
        }
        if timeZone != current.timeZone {
            reasons.append("Change the time zone to match the original.")
        }
        if location != current.location {
            reasons.append("Change the location to match this pair’s settings and the original.")
        }
        if url != current.url {
            reasons.append("Change the event link to match this pair’s settings and the original.")
        }
        if notes != current.notes {
            reasons
                .append("Change the notes to contain the links allowed by this pair and MinMaxCal’s tracking footer.")
        }
        return reasons
    }
}
