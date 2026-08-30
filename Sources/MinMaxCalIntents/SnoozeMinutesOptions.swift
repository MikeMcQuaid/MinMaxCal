import AppIntents
import MinMaxCalFeatures

/// The snooze durations Settings offers.
struct SnoozeMinutesOptions: DynamicOptionsProvider {
    /// Internal so tests can set it; the app registers it with `AppDependencyManager`.
    @Dependency var takeover: TakeoverModel

    func results() async -> [Int] {
        await MainActor.run { takeover.snoozeMinutes }
    }
}
