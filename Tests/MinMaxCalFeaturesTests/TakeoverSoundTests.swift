import Foundation
import MinMaxCalDomain
@testable import MinMaxCalFeatures
import Testing

struct TakeoverSoundTests {
    @Test
    func `lists the audio files of each folder once by name`() throws {
        let user: URL = Fixtures.scratchDirectory()
        let system: URL = Fixtures.scratchDirectory()
        for name in ["zebra.wav", "Alpha.aiff", "notes.txt", ".DS_Store"] {
            try Data().write(to: user.appending(path: name))
        }
        for name in ["Alpha.aiff", "Glass.aiff"] {
            try Data().write(to: system.appending(path: name))
        }

        let installed = TakeoverSound.installed(in: [user, system, user.appending(path: "missing")])

        #expect(installed.map(\.rawValue) == ["Alpha", "zebra", "Glass"])
    }
}
