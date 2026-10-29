import CoreML
@unsafe @preconcurrency import FluidAudio
import Foundation

enum RecordingError: LocalizedError {
    case audioOverrun
    case interrupted
    case invalidAudioFormat
    case microphoneDenied
    case noMicrophone

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Allow MinMaxCal microphone access in System Settings → Privacy & Security → Microphone."

        case .noMicrophone:
            "No microphone is available. Select an input device in System Settings → Sound."

        case .invalidAudioFormat:
            "The audio format changed or could not be read. Check your audio devices and start a new recording."

        case .audioOverrun:
            """
            Audio analysis could not keep up. The partial summary has been kept. Close busy apps, then choose Restart \
            Recording.
            """

        case .interrupted:
            "Audio capture was interrupted. The partial summary has been kept. Start a new recording to continue."
        }
    }
}
