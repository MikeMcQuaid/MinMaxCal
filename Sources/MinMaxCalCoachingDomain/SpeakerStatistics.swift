import Foundation

public struct SpeakerStatistics: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let speakingTime: TimeInterval
    public let speakingShare: Double
    public let meetingShare: Double
    public let longestTurn: TimeInterval
    public let currentTurn: TimeInterval
}
