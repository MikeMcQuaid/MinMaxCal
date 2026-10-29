import CoreML
@unsafe @preconcurrency import FluidAudio
import Foundation

struct AudioFrame {
    let samples: [Float]
    let time: TimeInterval
    let isMicrophone: Bool
    var isUnverifiedMicrophone = false
}
