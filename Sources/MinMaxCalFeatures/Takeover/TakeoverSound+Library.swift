import AudioToolbox
import Foundation
import MinMaxCalDomain
import UniformTypeIdentifiers

extension TakeoverSound {
    /// The sounds in the Sounds folders, the user's first.
    static var installed: [Self] {
        installed(in: folders)
    }

    /// The audio files in `folders` by name, each name once, in folder order.
    static func installed(in folders: [URL]) -> [Self] {
        audioFiles(in: folders).map { Self(rawValue: name(of: $0)) }
    }

    /// Plays the sound once as an alert, so it follows the alert volume and the Flash the screen
    /// accessibility setting.
    func play() {
        guard let sound = Self.systemSound(for: self) else {
            return
        }

        AudioServicesPlayAlertSound(sound)
    }

    /// Registered once per name and kept for the app's lifetime; there are only ever a few.
    private static var systemSounds: [String: SystemSoundID] = [:]

    /// A sandboxed app's home is its container, so the user's folder is reached through the
    /// account's home, which the app sandbox lets it read.
    private static var folders: [URL] {
        [
            URL(filePath: NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory()).appending(path: "Library/Sounds"),
            URL(filePath: "/Library/Sounds"),
            URL(filePath: "/System/Library/Sounds"),
        ]
    }

    private static func systemSound(for sound: Self) -> SystemSoundID? {
        if let registered = systemSounds[sound.rawValue] {
            return registered
        }

        guard let file = audioFiles(in: folders).first(where: { name(of: $0) == sound.rawValue }) else {
            return nil
        }

        var identifier: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(file as CFURL, &identifier) == kAudioServicesNoError else {
            return nil
        }

        systemSounds[sound.rawValue] = identifier
        return identifier
    }

    private static func audioFiles(in folders: [URL]) -> [URL] {
        var names = Set<String>()
        return folders.flatMap { folder in
            let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            return (files ?? [])
                .filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .audio) == true }
                .sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }
                .filter { names.insert(name(of: $0)).inserted }
        }
    }

    private static func name(of file: URL) -> String {
        file.deletingPathExtension().lastPathComponent
    }
}
