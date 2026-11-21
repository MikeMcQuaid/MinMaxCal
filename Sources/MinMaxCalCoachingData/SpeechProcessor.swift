import Foundation
import MinMaxCalCoachingDomain

actor SpeechProcessor {
    // MARK: Lifecycle

    init(
        // swiftlint:disable:next discouraged_default_parameter - Audio fixture defaults.
        reduceSpeakerEcho: Bool = true,
        // swiftlint:disable:next discouraged_default_parameter - Model-only fixtures omit recognition.
        transcribe: Bool = false,
        // swiftlint:disable:next discouraged_default_parameter - Per-user model cache.
        modelDirectory: URL = SpeechModels.defaultDirectory,
    ) async throws {
        microphone = MicrophoneSpeech(requiresVoiceActivity: reduceSpeakerEcho)
        diarizer = try RollingDiarizer(session: LSEENDSession(modelDirectory: modelDirectory))
        try Task.checkCancellation()
        transcriber = transcribe ? try await LiveTranscriber() : nil
    }

    // periphery:ignore - Dependency injection for model-free failure tests.
    init(diarizer: sending any DiarizationSession, transcriber: LiveTranscriber, reduceSpeakerEcho: Bool) {
        microphone = MicrophoneSpeech(requiresVoiceActivity: reduceSpeakerEcho)
        self.diarizer = RollingDiarizer(session: diarizer)
        self.transcriber = transcriber
    }

    // MARK: Internal

    func accept(_ frame: AudioFrame) async throws {
        guard frame.time.isFinite, frame.time >= 0 else {
            return
        }

        let end = frame.time + Double(frame.samples.count) / SpeechModels.sampleRate
        duration = max(duration, end)
        // swiftlint:disable:next no_magic_numbers - Scale RMS into the displayed microphone level.
        let level = min(1, sqrt(frame.samples.reduce(0) { $0 + $1 * $1 } / Float(max(1, frame.samples.count))) * 5)
        if frame.isMicrophone {
            microphoneOrigin = microphoneOrigin ?? frame.time
            microphoneLevel = level
            // swiftlint:disable:next no_magic_numbers - Display-only level floor; durations still require words.
            microphoneActive = microphone.requiresVoiceActivity ? frame.isMicrophoneSpeech : level > 0.01
        } else {
            remoteOrigin = remoteOrigin ?? frame.time
            meetingLevel = level
        }
        let origin = (frame.isMicrophone ? microphoneOrigin : remoteOrigin) ?? frame.time
        let expected = frame.isMicrophone ? microphoneSamples : remoteSamples
        let position = Int(((frame.time - origin) * SpeechModels.sampleRate).rounded())
        let gap = max(0, position - expected)
        // swiftlint:disable:next no_magic_numbers - Reject capture gaps longer than five seconds.
        guard gap < 80_000 else {
            throw RecordingError.interrupted
        }

        let samples = Array(repeating: Float.zero, count: gap) + frame.samples.dropFirst(max(0, expected - position))
        let time = origin + Double(expected) / SpeechModels.sampleRate
        if frame.isMicrophone {
            for interval in frame.microphoneActivity {
                microphone.observe(
                    start: max(interval.lowerBound, time + Double(gap) / SpeechModels.sampleRate),
                    end: min(interval.upperBound, time + Double(samples.count) / SpeechModels.sampleRate),
                    detected: true,
                )
            }
            microphoneSamples += samples.count
        } else {
            remoteSamples += samples.count
            try diarizer.process(samples, at: time)
        }
        if let transcriber {
            let result = await transcriber.accept(
                samples,
                isMicrophone: frame.isMicrophone,
                time: time,
            )
            transcript += microphone.confirm(result.words)
            if let error = result.error {
                throw error
            }
        }
    }

    func finish() async throws -> SpeechUpdate {
        try diarizer.finish()
        if let transcriber {
            let result = await transcriber.finish()
            transcript += microphone.confirm(result.words)
            if let error = result.error {
                throw error
            }
        }
        microphoneActive = false
        return snapshot()
    }

    func cancel() async {
        await transcriber?.cancel()
    }

    func snapshot() -> SpeechUpdate {
        let remote = diarizer.snapshot()
        var activeSpeakerIDs = [String]()
        if microphoneActive {
            activeSpeakerIDs.append("me")
        }
        // swiftlint:disable:next no_magic_numbers - Recent remote speaker activity.
        if duration - remote.duration < 2 {
            activeSpeakerIDs += remote.activeSpeakerIDs
        }
        return SpeechUpdate(
            segments: microphone.segments + remote.segments,
            duration: duration,
            microphoneLevel: microphoneLevel,
            meetingLevel: meetingLevel,
            activeSpeakerIDs: activeSpeakerIDs.sorted(),
            hasMeetingAudio: remoteOrigin != nil,
            transcript: transcript,
        )
    }

    // MARK: Private

    private let diarizer: RollingDiarizer
    private let transcriber: LiveTranscriber?
    private var microphone: MicrophoneSpeech
    private var transcript: [TranscriptWord] = []
    private var microphoneSamples = 0
    private var remoteSamples = 0
    private var microphoneOrigin: Double?
    private var remoteOrigin: Double?
    private var microphoneActive = false
    private var duration = 0.0
    private var microphoneLevel: Float = 0
    private var meetingLevel: Float = 0
}
