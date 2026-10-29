import Foundation

/// The supported duration of one speech-model session.
public enum RecordingSession {
    /// LS-EEND supports a single stream of up to one hour.
    public static let maximumDuration: TimeInterval = 3_600

    /// Identifies the hourly window for global recording timestamps.
    public static func index(at time: TimeInterval) -> Int {
        guard time.isFinite, time > 0, time < Double(Int.max) else {
            return 0
        }

        return Int(time / maximumDuration)
    }

    /// The time until the next remote-speaker reset, with recording continuing.
    public static func timeRemaining(at time: TimeInterval) -> TimeInterval {
        maximumDuration - max(0, time).truncatingRemainder(dividingBy: maximumDuration)
    }
}
