@unsafe @preconcurrency import AVFoundation
import CoreAudio

@MainActor
@safe
final class SystemAudioTap {
    // MARK: Internal

    nonisolated static func makeIOBlock(
        format: AVAudioFormat,
        output: AudioOutput,
    ) -> AudioDeviceIOBlock {
        { @Sendable _, data, time, _, _ in
            guard unsafe data.pointee.mNumberBuffers > 0,
                  unsafe data.pointee.mBuffers.mDataByteSize > 0,
                  unsafe data.pointee.mBuffers.mData != nil
            else {
                return
            }
            guard unsafe time.pointee.mFlags.contains(.hostTimeValid) else {
                output.continuation.finish(throwing: RecordingError.interrupted)
                return
            }
            guard let buffer = unsafe AVAudioPCMBuffer(
                pcmFormat: format,
                bufferListNoCopy: data,
                deallocator: nil,
            ) else {
                output.continuation.finish(throwing: RecordingError.invalidAudioFormat)
                return
            }

            output.receive(
                buffer,
                hostTime: unsafe time.pointee.mHostTime,
                isMicrophone: false,
            )
        }
    }

    func start(
        description: CATapDescription,
        output: AudioOutput,
    ) throws {
        do {
            try unsafe check(AudioHardwareCreateProcessTap(description, &tapID))
            var streamDescription = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try unsafe check(AudioObjectGetPropertyData(tapID, &formatAddress, 0, nil, &size, &streamDescription))
            guard let format = unsafe AVAudioFormat(streamDescription: &streamDescription),
                  format.sampleRate > 0, format.channelCount > 0
            else {
                throw RecordingError.invalidAudioFormat
            }

            let composition: [String: Any] = [
                kAudioAggregateDeviceNameKey: "MinMaxCal audio capture",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: false,
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapUIDKey: description.uuid.uuidString,
                        kAudioSubTapDriftCompensationKey: true,
                    ],
                ], // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
            ]
            try unsafe check(AudioHardwareCreateAggregateDevice(composition as CFDictionary, &deviceID))
            try unsafe check(AudioDeviceCreateIOProcIDWithBlock(
                &ioProcID,
                deviceID,
                queue,
                Self.makeIOBlock(
                    format: format,
                    output: output,
                ),
            ))
            let listener: AudioObjectPropertyListenerBlock = { @Sendable _, _ in
                output.continuation.finish(throwing: RecordingError.interrupted)
            }
            try unsafe check(AudioObjectAddPropertyListenerBlock(tapID, &formatAddress, queue, listener))
            unsafe formatListener = listener
            try unsafe check(AudioDeviceStart(deviceID, ioProcID))
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let listener = unsafe formatListener {
            unsafe AudioObjectRemovePropertyListenerBlock(tapID, &formatAddress, queue, listener)
            unsafe formatListener = nil
        }
        if let callback = unsafe ioProcID {
            unsafe AudioDeviceStop(deviceID, callback)
            unsafe AudioDeviceDestroyIOProcID(deviceID, callback)
            unsafe ioProcID = nil
        }
        if deviceID != 0 {
            AudioHardwareDestroyAggregateDevice(deviceID)
            deviceID = 0
        }
        if tapID != 0 {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
        }
    }

    // MARK: Private

    private var tapID: AudioObjectID = 0
    private var deviceID: AudioObjectID = 0
    private var ioProcID: AudioDeviceIOProcID?
    private var formatListener: AudioObjectPropertyListenerBlock?
    private var formatAddress: AudioObjectPropertyAddress = .init(
        mSelector: kAudioTapPropertyFormat,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain,
    )
    private let queue: DispatchQueue = .init(label: "com.mikemcquaid.MinMaxCal.system-audio")

    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: """
                    System audio capture failed (\(status)). Check MinMaxCal’s audio-only recording permission \
                    in System Settings → Privacy & Security and the selected audio device.
                    """,
                ], // swiftformat:disable:this trailingCommas - SwiftLint requires the comma.
            )
        }
    }
}
