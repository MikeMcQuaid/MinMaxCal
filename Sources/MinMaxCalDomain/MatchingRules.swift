import Foundation

public struct MatchingRules: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(genericTitles: [String], jitsiHosts: [String]) {
        self.genericTitles = genericTitles
        self.jitsiHosts = jitsiHosts
    }

    // MARK: Public

    public static let `default`: Self = .init(
        genericTitles: ["Busy", "Untitled", "New Event", "Private", "Tentative"],
        jitsiHosts: [],
    )
    public static let builtInJitsiHost = "meet.jit.si"

    public var genericTitles: [String]
    public var jitsiHosts: [String]

    public static func normalise(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    public func isGeneric(_ title: String) -> Bool {
        let normalised = Self.normalise(title)
        return normalised.isEmpty || genericTitles.map(Self.normalise).contains(normalised)
    }

    public func isJitsiHost(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        return lowercased == Self.builtInJitsiHost || jitsiHosts.map { $0.lowercased() }.contains(lowercased)
    }
}
