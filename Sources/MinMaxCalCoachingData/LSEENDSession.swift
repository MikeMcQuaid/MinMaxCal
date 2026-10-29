@unsafe @preconcurrency import FluidAudio
import Foundation
import MinMaxCalCoachingDomain

final class LSEENDSession: DiarizationSession {
    // MARK: Lifecycle

    init(modelDirectory: URL) throws {
        diarizer = try LSEENDDiarizer(
            model: LSEENDModel(modelURL: modelDirectory.appending(path: Repo.lseendDihard3.folderName)
                .appending(path: SpeechModels.diarizerPath)),
            timelineConfig: DiarizerTimelineConfig(
                // swiftlint:disable:next no_magic_numbers - Speech-model hysteresis thresholds.
                minFramesOn: 2,
                // swiftlint:disable:next no_magic_numbers - Speech-model hysteresis thresholds.
                minFramesOff: 2,
                maxStoredFrames: 100,
            ),
        )
    }

    // MARK: Internal

    func process(_ samples: [Float]) throws {
        _ = try diarizer.process(samples: samples, sourceSampleRate: SpeechModels.sampleRate)
        duration += Double(samples.count) / SpeechModels.sampleRate
    }

    func finish() throws {
        _ = try diarizer.finalizeSession()
    }

    func reset() {
        diarizer.reset()
        duration = 0
    }

    func snapshot() -> SpeechUpdate {
        var segments = [SpeechSegment]()
        var activeSpeakerIDs = [String]()
        for speaker in diarizer.timeline.speakers.values {
            let identifier = "speaker-\(speaker.index + 1)"
            if let last = speaker.lastSegment,
               // swiftlint:disable:next no_magic_numbers - Timeline hysteresis and recent activity.
               last.endTime >= diarizer.timeline.finalizedDuration - 0.1, duration - Double(last.endTime) < 2
            // swiftlint:disable:next opening_brace - SwiftFormat wraps multiline conditions.
            {
                activeSpeakerIDs.append(identifier)
            }
            for segment in speaker.finalizedSegments + speaker.tentativeSegments {
                let end = min(duration, Double(segment.endTime))
                if end > Double(segment.startTime) {
                    segments.append(.init(speakerID: identifier, start: Double(segment.startTime), end: end))
                }
            }
        }
        return SpeechUpdate(segments: segments, duration: duration, activeSpeakerIDs: activeSpeakerIDs)
    }

    // MARK: Private

    private let diarizer: LSEENDDiarizer
    private var duration = 0.0
}
