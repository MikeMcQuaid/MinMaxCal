import Foundation

enum ListField {
    static func strings(from text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    static func integers(from text: String) -> [Int] {
        strings(from: text).compactMap { Int($0) }.filter { $0 > 0 }
    }
}
