@unsafe @preconcurrency import AVFoundation
import CoreMedia
import Speech

/// One converter and one continuous recognition timeline per captured source.
final class SpeechInput {
    // MARK: Lifecycle

    init(format: AVAudioFormat) throws {
        guard let source = AVAudioFormat(standardFormatWithSampleRate: SpeechModels.sampleRate, channels: 1),
              let audioConverter = AVAudioConverter(from: source, to: format)
        else {
            throw RecordingError.invalidAudioFormat
        }

        converter = audioConverter
    }

    // MARK: Internal

    func input(samples: [Float], at time: Double) throws -> AnalyzerInput? {
        guard samples.isEmpty == false else {
            return nil
        }
        guard let source = AVAudioPCMBuffer(
                  pcmFormat: converter.inputFormat,
                  frameCapacity: AVAudioFrameCount(samples.count),
              ),
              let data = unsafe source.floatChannelData?[0]
        else {
            throw RecordingError.invalidAudioFormat
        }

        origin = origin ?? time
        source.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { samples in
            // swiftlint:disable:next force_unwrapping - Non-empty sample buffer.
            unsafe data.update(from: samples.baseAddress!, count: samples.count)
        }
        let capacity =
            AVAudioFrameCount((Double(samples.count) * converter.outputFormat.sampleRate / SpeechModels.sampleRate)
                    .rounded(.up)) + 1
        return try convert(source: source, capacity: capacity)
    }

    func finish() throws -> [AnalyzerInput] {
        guard origin != nil, finished == false else {
            return []
        }

        finished = true
        var tail = [AnalyzerInput]()
        // swiftlint:disable:next no_magic_numbers - Drain the converter in bounded buffers.
        while let buffer = try convert(source: nil, capacity: 4_096) {
            tail.append(buffer)
        }
        return tail
    }

    // MARK: Private

    private let converter: AVAudioConverter
    private var started = false
    private var finished = false
    private var origin: Double?

    private func convert(source: AVAudioPCMBuffer?, capacity: AVAudioFrameCount) throws -> AnalyzerInput? {
        guard let converted = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            throw RecordingError.invalidAudioFormat
        }

        var consumed = false
        var error: NSError?
        let result = unsafe converter.convert(to: converted, error: &error) { _, inputStatus in
            guard let source else {
                unsafe inputStatus.pointee = .endOfStream
                return nil
            }

            if consumed {
                unsafe inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            unsafe inputStatus.pointee = .haveData
            return source
        }
        if let error {
            throw error
        }
        guard result != .error else {
            throw RecordingError.invalidAudioFormat
        }
        guard converted.frameLength > 0 else {
            return nil
        }

        // Original capture timestamps do not describe resampled buffer boundaries.
        let start: CMTime? = started ? nil : CMTime(
            seconds: origin ?? 0,
            preferredTimescale: CMTimeScale(SpeechModels.sampleRate),
        )
        started = true
        return AnalyzerInput(buffer: converted, bufferStartTime: start)
    }
}
