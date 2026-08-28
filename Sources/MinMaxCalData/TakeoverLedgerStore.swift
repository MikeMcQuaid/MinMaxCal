import Foundation
import MinMaxCalDomain
import Synchronization

/// Reads and writes the takeover ledger file. It is the file's only writer, so after the first read
/// the ledger is served from memory and every save writes through.
public final class TakeoverLedgerStore: Sendable {
    // MARK: Lifecycle

    public init(file: URL = defaultFile) {
        self.file = file
    }

    // MARK: Public

    public static let defaultFile = URL.applicationSupportDirectory
        .appending(path: "MinMaxCal", directoryHint: .isDirectory)
        .appending(path: "takeovers.json")

    public func load() -> TakeoverLedger {
        cached.withLock { ledger in
            if let ledger {
                return ledger
            }

            let read = read()
            ledger = read
            return read
        }
    }

    public func save(_ ledger: TakeoverLedger, at now: Date) {
        let pruned = ledger.pruned(at: now)
        cached.withLock { $0 = pruned }
        let directory = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(pruned).write(to: file, options: .atomic)
    }

    // MARK: Private

    private let file: URL
    private let cached: Mutex<TakeoverLedger?> = .init(nil)

    private func read() -> TakeoverLedger {
        guard let data = try? Data(contentsOf: file) else {
            return .empty
        }

        return (try? JSONDecoder().decode(TakeoverLedger.self, from: data)) ?? .empty
    }
}
