import Foundation

public struct MatchingRules: Codable, Hashable, Sendable {
    // MARK: Lifecycle

    public init(genericTitles: [String], jitsiHosts: [String], homeTerms: [String] = Self.default.homeTerms) {
        self.genericTitles = genericTitles
        self.jitsiHosts = jitsiHosts
        self.homeTerms = homeTerms
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genericTitles = try container.decode([String].self, forKey: .genericTitles)
        jitsiHosts = try container.decode([String].self, forKey: .jitsiHosts)
        homeTerms = try container.decodeIfPresent([String].self, forKey: .homeTerms) ?? Self.default.homeTerms
    }

    // MARK: Public

    public static let `default`: Self = .init(
        genericTitles: ["Busy", "Untitled", "New Event", "Private", "Tentative"],
        jitsiHosts: [],
        homeTerms: ["Edinburgh", "Scotland", "EH*"],
    )
    public static let builtInJitsiHost = "meet.jit.si"

    public var genericTitles: [String]
    public var jitsiHosts: [String]
    /// Words dropped from displayed locations because they are where the user already is; a
    /// trailing `*` makes a term a prefix, so `EH*` drops the local postcodes.
    public var homeTerms: [String]

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

    public func isHomeTerm(_ word: String) -> Bool {
        let normalised = Self.normalise(word)
        return homeTerms.contains { term in
            if term.hasSuffix("*") {
                return normalised.hasPrefix(Self.normalise(String(term.dropLast())))
            }
            return normalised == Self.normalise(term)
        }
    }
}
