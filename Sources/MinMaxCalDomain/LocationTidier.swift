import Foundation

/// Shortens a location for display by dropping the parts that only say where the user already is.
public enum LocationTidier {
    // MARK: Public

    /// The location's parts (split on commas and line breaks) without home terms or repeats, joined
    /// with commas; unchanged when nothing would be left.
    public static func display(_ location: String, rules: MatchingRules) -> String {
        var seen = Set<String>()
        let parts = location.split { $0 == "," || $0.isNewline }.compactMap { part -> String? in
            let kept = withoutHomeTerms(part.split(whereSeparator: \.isWhitespace).map(String.init), rules: rules)
            let text = kept.joined(separator: " ")
            return kept.isEmpty || seen.insert(MatchingRules.normalise(text)).inserted == false ? nil : text
        }
        let tidied = parts.joined(separator: ", ")
        return tidied.isEmpty ? location : tidied
    }

    // MARK: Private

    /// A dropped postcode takes its inward half (`2EL` after `EH1`) with it.
    private static func withoutHomeTerms(_ words: [String], rules: MatchingRules) -> [String] {
        var kept = [String]()
        var droppedPrevious = false
        for word in words {
            let inwardCode = droppedPrevious && word.wholeMatch(of: /\d[A-Za-z]{2}/) != nil
            droppedPrevious = rules.isHomeTerm(word) || inwardCode
            if droppedPrevious == false {
                kept.append(word)
            }
        }
        return kept
    }
}
