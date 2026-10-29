import FluidAudio
import Foundation

struct EchoAudioBuffer {
    // MARK: Internal

    struct Pair {
        let microphone: [Float]
        let reference: [Float]
        let time: Double
        let hasCompleteReference: Bool
    }

    mutating func append(_ frame: AudioFrame) throws {
        guard frame.samples.isEmpty == false else {
            return
        }

        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        let position = Int((frame.time * 16_000).rounded())
        if frame.isMicrophone {
            try microphone.append(
                frame.samples,
                at: position,
            )
        } else {
            try reference.append(
                frame.samples,
                at: position,
            )
        }
        latest = max(
            latest,
            position + frame.samples.count,
        )
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        reference.discard(before: microphone.start ?? max(0, reference.end - 32_000))
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        guard microphone.samples.count <= 32_000, reference.samples.count <= 32_000 else {
            throw RecordingError.audioOverrun
        }
    }

    // swiftlint:disable:next discouraged_default_parameter - Migrated fixture defaults.
    mutating func next(finalising: Bool = false) -> Pair? {
        guard let start = microphone.start, microphone.samples.isEmpty == false else {
            return nil
        }

        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        let count = min(4_096, microphone.samples.count)
        let end = start + count
        // Allow callback reordering without waiting forever when playback is silent.
        // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
        guard finalising || (count == 4_096 && (reference.end >= end || latest - end >= 8_000)) else {
            return nil
        }

        var playback = [Float](
            repeating: 0,
            count: count,
        )
        if let referenceStart = reference.start {
            let lower = max(start, referenceStart)
            let upper = min(end, reference.end)
            if upper > lower {
                playback.replaceSubrange(
                    (lower - start) ..< (upper - start),
                    with: reference.samples[(lower - referenceStart) ..< (upper - referenceStart)],
                )
            }
        }
        let pair = Pair(
            microphone: Array(microphone.samples.prefix(count)),
            reference: playback,
            // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
            time: Double(start) / 16_000,
            hasCompleteReference: reference.start.map { $0 <= start } == true && reference.end >= end
                && reference.gaps.contains { $0.overlaps(start ..< end) } == false,
        )
        microphone.discard(before: end)
        reference.discard(before: end)
        return pair
    }

    // MARK: Private

    private struct Track {
        var start: Int?
        var samples: [Float] = []
        var gaps: [Range<Int>] = []

        var end: Int {
            (start ?? 0) + samples.count
        }

        mutating func append(
            _ audio: [Float],
            at position: Int,
        ) throws {
            if start == nil {
                start = position
            }
            let gap = max(
                0,
                position - end,
            )
            // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
            guard gap < 80_000 else {
                throw RecordingError.interrupted
            }

            let newSamples = audio.dropFirst(max(
                0,
                end - position,
            ))
            // swiftlint:disable:next no_magic_numbers - Speech timing and model thresholds.
            guard samples.count + gap + newSamples.count <= 96_000 else {
                throw RecordingError.audioOverrun
            }

            if gap > 0 {
                gaps.append(end ..< position)
            }
            samples.append(contentsOf: repeatElement(
                0,
                count: gap,
            ))
            samples.append(contentsOf: newSamples)
        }

        mutating func discard(before position: Int) {
            guard let start else {
                return
            }

            let count = min(
                samples.count,
                max(
                    0,
                    position - start,
                ),
            )
            samples.removeFirst(count)
            self.start = start + count
            gaps.removeAll { $0.upperBound <= start + count }
        }
    }

    private var microphone: Track = .init()
    private var reference: Track = .init()
    private var latest = 0
}
