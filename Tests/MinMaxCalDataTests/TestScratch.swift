import Foundation

enum TestScratch {
    static func directory(_ file: String = #filePath) -> URL {
        let checkout = URL(filePath: file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = checkout.appending(path: ".test-scratch").appending(path: UUID().uuidString)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
