@testable import MinMaxCalCoachingData
import Testing

@Test(arguments: [true, false])
func `audio pairs follow timestamps rather than callback order`(microphoneFirst: Bool) throws {
    var buffer = EchoAudioBuffer()
    let mic = AudioFrame(
        samples: Array(
            repeating: 1,
            count: 4_096,
        ),
        time: 0.032,
        isMicrophone: true,
    )
    let reference = AudioFrame(
        samples: (0 ..< 4_608).map(Float.init),
        time: 0,
        isMicrophone: false,
    )
    try buffer.append(microphoneFirst ? mic : reference)
    #expect(buffer.next() == nil)
    try buffer.append(microphoneFirst ? reference : mic)
    let next = buffer.next()
    let pair = try #require(next)
    #expect(pair.time == 0.032)
    #expect(pair.microphone == mic.samples)
    #expect(pair.reference == Array(reference.samples[512 ..< 4_608]))
    #expect(pair.hasCompleteReference)
    #expect(buffer.next(finalising: true) == nil)
}

@Test
func `echo pairing waits for reference and flushes the tail`() throws {
    var buffer = EchoAudioBuffer()
    try buffer.append(.init(
        samples: Array(
            repeating: 1,
            count: 1_000,
        ),
        time: 2,
        isMicrophone: true,
    ))
    #expect(buffer.next() == nil)
    try buffer.append(.init(
        samples: Array(
            repeating: 2,
            count: 800,
        ),
        time: 2.0125,
        isMicrophone: false,
    ))
    let next = buffer.next(finalising: true)
    let pair = try #require(next)
    #expect(pair.time == 2)
    #expect(pair.microphone.count == 1_000)
    #expect(pair.reference == Array(
        repeating: 0,
        count: 200,
    ) + Array(
        repeating: 2,
        count: 800,
    ))
    #expect(pair.hasCompleteReference == false)
    #expect(buffer.next(finalising: true) == nil)
}

@Test
func `no playback does not stall microphone analysis`() throws {
    var buffer = EchoAudioBuffer()
    try buffer.append(.init(
        samples: Array(
            repeating: 1,
            count: 12_288,
        ),
        time: 0,
        isMicrophone: true,
    ))
    let next = buffer.next()
    let pair = try #require(next)
    #expect(pair.reference == Array(
        repeating: 0,
        count: 4_096,
    ))
    #expect(pair.microphone.count == 4_096)
    #expect(pair.hasCompleteReference == false)
}

@Test
func `missing playback inside a block is unverified but captured silence is valid`() throws {
    var buffer = EchoAudioBuffer()
    try buffer.append(.init(
        samples: Array(
            repeating: 1,
            count: 8_192,
        ),
        time: 0,
        isMicrophone: true,
    ))
    try buffer.append(.init(
        samples: Array(
            repeating: 0,
            count: 1_024,
        ),
        time: 0,
        isMicrophone: false,
    ))
    try buffer.append(.init(
        samples: Array(
            repeating: 0,
            count: 6_144,
        ),
        time: 0.128,
        isMicrophone: false,
    ))
    let incomplete = buffer.next()
    let complete = buffer.next()
    #expect(incomplete?.hasCompleteReference == false)
    #expect(complete?.hasCompleteReference == true)
}

@Test
func `repeated audio is not counted twice and buffers stay bounded`() throws {
    var buffer = EchoAudioBuffer()
    let frame = AudioFrame(
        samples: Array(
            repeating: 1,
            count: 4_096,
        ),
        time: 0,
        isMicrophone: true,
    )
    try buffer.append(frame)
    try buffer.append(frame)
    #expect(buffer.next(finalising: true)?.microphone.count == 4_096)
    #expect(buffer.next(finalising: true) == nil)
    #expect(throws: (any Error).self) {
        try buffer.append(.init(
            samples: Array(
                repeating: 0,
                count: 64_000,
            ),
            time: 0.256,
            isMicrophone: true,
        ))
    }
}
