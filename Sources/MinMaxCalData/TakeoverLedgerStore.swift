import Foundation
import MinMaxCalDomain

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
        guard let data = try? Data(contentsOf: file) else {
            return .empty
        }

        return (try? JSONDecoder().decode(TakeoverLedger.self, from: data)) ?? .empty
    }

    public func save(_ ledger: TakeoverLedger, at now: Date) {
        let directory = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(ledger.pruned(at: now)).write(to: file, options: .atomic)
    }

    // MARK: Private

    private let file: URL
}
