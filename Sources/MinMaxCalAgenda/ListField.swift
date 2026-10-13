import Foundation

/// Comma-separated lists as text field formats, so a field commits when editing ends rather than
/// rebuilding the agenda on every keystroke.
nonisolated package enum ListField {
    nonisolated struct Strings: ParseableFormatStyle, ParseStrategy {
        var parseStrategy: Self {
            self
        }

        func format(_ value: [String]) -> String {
            value.joined(separator: ", ")
        }

        func parse(_ value: String) -> [String] {
            strings(from: value)
        }
    }

    static func strings(from text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
