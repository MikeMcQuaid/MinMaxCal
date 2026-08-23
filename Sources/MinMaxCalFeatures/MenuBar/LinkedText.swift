import AppKit
import Foundation
import MinMaxCalDomain

/// Turns untrusted notes into text with clickable `http(s)` links: HTML is reduced to its text and
/// anchors through AppKit's importer, plain text gets its bare URLs detected.
enum LinkedText {
    // MARK: Internal

    static func attributed(_ notes: String) -> AttributedString {
        var result = looksLikeHTML(notes) ? fromHTML(notes) ?? AttributedString(notes) : AttributedString(notes)
        // The importer ends every paragraph with a line break; the last line of text is the bottom.
        while let last = result.characters.last, last.isWhitespace {
            result.characters.removeLast()
        }
        while let first = result.characters.first, first.isWhitespace {
            result.characters.removeFirst()
        }
        let plain = String(result.characters)
        for link in JoinLinkDetector.links(in: plain) where link.url.scheme != "zoommtg" {
            guard let range = Range(link.range, in: result), result[range].runs.allSatisfy({ $0.link == nil }) else {
                continue
            }

            result[range].link = link.url
        }
        return result
    }

    static func looksLikeHTML(_ text: String) -> Bool {
        text.contains(tagPattern)
    }

    // MARK: Private

    private static let tagPattern = /<\/?[A-Za-z][^>]*>/
    /// Anything that would make the importer fetch a resource is removed before it runs.
    private static let loadingElementNames = "img|link|script|style|iframe|object|embed|video|audio|source"
    private static let loadingElements = try? Regex("<(?:\\/?)(?:\(loadingElementNames))\\b[^>]*>").ignoresCase()
    private static let scriptAndStyleBlocks = try? Regex("<(script|style)\\b[^>]*>[\\s\\S]*?<\\/\\1\\s*>").ignoresCase()
    private static let webSchemes: Set<String> = ["http", "https"]

    private static func fromHTML(_ html: String) -> AttributedString? {
        guard let loadingElements, let scriptAndStyleBlocks else {
            return nil
        }

        let stripped = html.replacing(scriptAndStyleBlocks, with: "").replacing(loadingElements, with: "")
        guard let data = stripped.data(using: .utf8),
              let imported = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil,
              )
        else {
            return nil
        }

        let source = AttributedString(imported)
        var result = AttributedString(String(source.characters))
        for run in source.runs {
            guard let link = run.link, webSchemes.contains(link.scheme?.lowercased() ?? "") else {
                continue
            }

            let start = source.characters.distance(from: source.startIndex, to: run.range.lowerBound)
            let length = source.characters.distance(from: run.range.lowerBound, to: run.range.upperBound)
            let lower = result.index(result.startIndex, offsetByCharacters: start)
            result[lower ..< result.index(lower, offsetByCharacters: length)].link = link
        }
        return result
    }
}
