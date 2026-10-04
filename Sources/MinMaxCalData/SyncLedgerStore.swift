import Foundation
import MinMaxCalDomain
import Synchronization

public final class SyncLedgerStore: Sendable {
    // MARK: Lifecycle

    public init(file: URL = defaultFile) {
        self.file = file
    }

    // MARK: Public

    public static let defaultFile = URL.applicationSupportDirectory
        .appending(path: "MinMaxCal", directoryHint: .isDirectory)
        .appending(path: "sync.json")

    public func load() throws -> [SyncLink] {
        try cached.withLock { links in
            if let links {
                return links
            }
            guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
                links = []
                return []
            }

            let read = try JSONDecoder().decode([SyncLink].self, from: Data(contentsOf: file))
            links = read
            return read
        }
    }

    public func save(_ links: [SyncLink]) throws {
        try cached.withLock { cached in
            if cached == links {
                return
            }
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try JSONEncoder().encode(links).write(to: file, options: .atomic)
            cached = links
        }
    }

    // MARK: Private

    private let file: URL
    // swiftlint:disable:next discouraged_optional_collection - nil means the ledger has not been read.
    private let cached: Mutex<[SyncLink]?> = .init(nil)
}
