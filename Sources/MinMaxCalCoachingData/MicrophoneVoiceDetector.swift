import CoreAudio
import Foundation

@MainActor
@safe
final class MicrophoneVoiceDetector {
    // MARK: Internal

    func start(output: AudioOutput) throws {
        captureOutput = output
        do {
            device = try Self.value(
                kAudioHardwarePropertyDefaultInputDevice,
                object: AudioObjectID(kAudioObjectSystemObject),
                scope: kAudioObjectPropertyScopeGlobal,
            )
            guard device != kAudioObjectUnknown,
                  unsafe AudioObjectHasProperty(device, &enableAddress),
                  unsafe AudioObjectHasProperty(device, &stateAddress)
            else {
                throw RecordingError.voiceDetectionUnavailable
            }

            previousEnabled = try Self.value(kAudioDevicePropertyVoiceActivityDetectionEnable, object: device)
            let handler: AudioObjectPropertyListenerBlock = { @Sendable [device] _, _ in
                do {
                    try output.updateVoiceActivity(Self.value(
                        kAudioDevicePropertyVoiceActivityDetectionState,
                        object: device,
                    ) != 0)
                } catch {
                    output.continuation.finish(throwing: error)
                }
            }
            try unsafe Self.check(AudioObjectAddPropertyListenerBlock(device, &stateAddress, callbackQueue, handler))
            unsafe listener = handler
            var enabled: UInt32 = 1
            try unsafe Self.check(AudioObjectSetPropertyData(
                device,
                &enableAddress,
                0,
                nil,
                UInt32(MemoryLayout.size(ofValue: enabled)),
                &enabled,
            ))
            try callbackQueue.sync { [device] in
                try output.updateVoiceActivity(Self.value(
                    kAudioDevicePropertyVoiceActivityDetectionState,
                    object: device,
                ) != 0)
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        captureOutput?.stopVoiceActivityUpdates()
        captureOutput = nil
        if let handler = unsafe listener {
            unsafe AudioObjectRemovePropertyListenerBlock(device, &stateAddress, callbackQueue, handler)
            unsafe listener = nil
        }
        if var originalValue = previousEnabled {
            unsafe AudioObjectSetPropertyData(
                device,
                &enableAddress,
                0,
                nil,
                UInt32(MemoryLayout.size(ofValue: originalValue)),
                &originalValue,
            )
        }
        previousEnabled = nil
    }

    // MARK: Private

    private let callbackQueue: DispatchQueue = .init(label: "MinMaxCal.microphone-voice-activity", qos: .userInitiated)
    private var captureOutput: AudioOutput?

    private var device: AudioObjectID = kAudioObjectUnknown
    private var previousEnabled: UInt32?
    private var listener: AudioObjectPropertyListenerBlock?
    private var enableAddress: AudioObjectPropertyAddress = .init(
        mSelector: kAudioDevicePropertyVoiceActivityDetectionEnable,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain,
    )
    private var stateAddress: AudioObjectPropertyAddress = .init(
        mSelector: kAudioDevicePropertyVoiceActivityDetectionState,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain,
    )

    nonisolated private static func value(
        _ selector: AudioObjectPropertySelector,
        object: AudioObjectID,
        scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeInput,
    ) throws -> UInt32 {
        var property = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain,
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        try unsafe Self.check(AudioObjectGetPropertyData(object, &property, 0, nil, &size, &value))
        return value
    }

    nonisolated private static func check(_ result: OSStatus) throws {
        guard result == noErr else {
            throw RecordingError.voiceDetectionUnavailable
        }
    }
}
