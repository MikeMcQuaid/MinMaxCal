import Foundation

// MARK: - SpeakerStatistics

// MARK: - MeetingStatistics

public struct MeetingStatistics: Codable, Sendable {
    // MARK: Lifecycle

    // swiftlint:disable:next cyclomatic_complexity function_body_length - One migrated audio operation.
    public init(meeting: Meeting) {
        hasUnverifiedSpeech = meeting.hasUnverifiedSpeech
        let duration = meeting.duration.isFinite ? max(0, meeting.duration) : 0
        let grouped = Dictionary(
            grouping: meeting.segments.filter { segment in
                segment.start.isFinite && segment.end.isFinite && segment.end > segment.start
            },
            by: \.speakerID,
        ).mapValues { segments in
            Self.union(segments.compactMap { segment in
                let start = max(0, segment.start)
                let end = min(duration, segment.end)
                return end > start ? start ..< end : nil
            })
        }
        let total = grouped.values.flatMap(\.self).reduce(0) { $0 + $1.upperBound - $1.lowerBound }
        let all = Self.union(grouped.values.flatMap(\.self))
        silence = max(
            0,
            duration - all.reduce(0) { $0 + $1.upperBound - $1.lowerBound },
        )

        var active = 0
        var previous = 0.0
        var overlapping = 0.0
        for (time, change) in grouped.values
            .flatMap(\.self)
            .flatMap({ [($0.lowerBound, 1), ($0.upperBound, -1)] })
            .sorted(by: { $0.0 < $1.0 })
        // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
        {
            if active > 1 {
                overlapping += time - previous
            }
            active += change
            previous = time
        }
        overlap = overlapping

        speakers = Set(grouped.keys)
            .union(["me"])
            .sorted { first, second in
                if first == "me" {
                    return true
                }
                if second == "me" {
                    return false
                }
                return first.localizedStandardCompare(second) == .orderedAscending
            }
            // swiftlint:disable:next closure_body_length - One migrated audio operation.
            .map { id in
                let ranges = grouped[id] ?? []
                let other = Self.union(grouped.filter { $0.key != id }.values.flatMap(\.self))
                let speaking = ranges.reduce(0) { $0 + $1.upperBound - $1.lowerBound }
                var solo = [Range<Double>]()
                var otherIndex = 0
                for range in ranges {
                    var start = range.lowerBound
                    while otherIndex < other.count, other[otherIndex].upperBound <= start {
                        otherIndex += 1
                    }
                    var index = otherIndex
                    while index < other.count, other[index].lowerBound < range.upperBound {
                        let interruption = other[index]
                        if interruption.lowerBound > start {
                            solo.append(start ..< interruption.lowerBound)
                        }
                        start = max(start, interruption.upperBound)
                        index += 1
                    }
                    if start < range.upperBound {
                        solo.append(start ..< range.upperBound)
                    }
                }
                var turns = [Range<Double>]()
                otherIndex = 0
                for range in solo {
                    while otherIndex < other.count, other[otherIndex].upperBound <= (turns.last?.upperBound ?? 0) {
                        otherIndex += 1
                    }
                    // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
                    if let last = turns.last, range.lowerBound - last.upperBound <= 0.75,
                       otherIndex == other.count || other[otherIndex].lowerBound >= range.lowerBound
                    // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
                    {
                        turns[turns.count - 1] = last.lowerBound ..< range.upperBound
                    } else {
                        turns.append(range)
                    }
                }
                return SpeakerStatistics(
                    id: id,
                    speakingTime: speaking,
                    speakingShare: total > 0 ? speaking / total : 0,
                    meetingShare: duration > 0 ? speaking / duration : 0,
                    longestTurn: turns.lazy.map { $0.upperBound - $0.lowerBound }.max() ?? 0,
                    currentTurn: turns.last.map { turn in
                        // swiftlint:disable:next no_magic_numbers - Coaching durations in seconds.
                        duration - turn.upperBound <= 0.75 && (other.last?.upperBound ?? 0) <= turn.upperBound
                            ? turn.upperBound - turn.lowerBound : 0
                    } ?? 0,
                )
            }
    }

    // MARK: Public

    public let speakers: [SpeakerStatistics]
    public let silence: TimeInterval
    public let overlap: TimeInterval
    public let hasUnverifiedSpeech: Bool

    // MARK: Private

    private static func union(_ ranges: [Range<Double>]) -> [Range<Double>] {
        var result = [Range<Double>]()
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound ..< max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
