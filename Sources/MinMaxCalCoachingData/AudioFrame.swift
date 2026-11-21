import Foundation

struct AudioFrame {
    let samples: [Float]
    let time: TimeInterval
    let isMicrophone: Bool
    var microphoneActivity: [Range<Double>] = []

    var isMicrophoneSpeech: Bool {
        microphoneActivity.isEmpty == false
    }
}
