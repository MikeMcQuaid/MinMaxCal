import AppIntents
import MinMaxCalIntents

// MARK: - AppShortcuts

/// The phrases Siri and Spotlight offer for the Features intents; App Shortcuts must sit in the app
/// bundle.
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetNextItemIntent(),
            phrases: ["What is next in \(.applicationName)"],
            shortTitle: "Get Next Item",
            systemImageName: "calendar",
        )
        AppShortcut(
            intent: JoinNextMeetingIntent(),
            phrases: ["Join my next meeting with \(.applicationName)"],
            shortTitle: "Join Next Meeting",
            systemImageName: "video",
        )
        AppShortcut(
            intent: CompleteNextReminderIntent(),
            phrases: ["Complete my next reminder in \(.applicationName)"],
            shortTitle: "Complete Next Reminder",
            systemImageName: "checkmark.circle",
        )
        AppShortcut(
            intent: SnoozeTakeoverIntent(),
            phrases: ["Snooze the \(.applicationName) takeover"],
            shortTitle: "Snooze Takeover",
            systemImageName: "zzz",
        )
        AppShortcut(
            intent: PreviewTakeoverIntent(),
            phrases: ["Preview a \(.applicationName) takeover"],
            shortTitle: "Preview Takeover",
            systemImageName: "rectangle.inset.filled",
        )
    }
}
