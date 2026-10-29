import Foundation

// MARK: - CoachingReminder

/// Tracks target crossings with a two-minute cooldown.
public struct CoachingReminder {
    // MARK: Lifecycle

    /// Creates a fresh reminder state.
    public init() {}

    // MARK: Public

    /// Consumes a target state and returns whether a fresh crossing may notify.
    public mutating func shouldNotify(
        needsRoom: Bool,
        at time: TimeInterval,
    ) -> Bool {
        defer { wasAboveTarget = needsRoom }
        guard needsRoom,
              wasAboveTarget == false,
              // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
              time - (lastNotification ?? -.infinity) >= 120
        else {
            return false
        }

        lastNotification = time
        return true
    }

    // MARK: Private

    private var wasAboveTarget = false
    private var lastNotification: TimeInterval?
}

// MARK: - MeetingNotifier
