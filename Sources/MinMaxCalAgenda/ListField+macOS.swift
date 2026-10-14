#if os(macOS)
import Foundation

package extension ListField {
    nonisolated struct Integers: ParseableFormatStyle, ParseStrategy {
        // MARK: Lifecycle

        package init() {}

        // MARK: Package

        package var parseStrategy: Self {
            self
        }

        package func format(_ value: [Int]) -> String {
            value.map(String.init).joined(separator: ", ")
        }

        package func parse(_ value: String) -> [Int] {
            strings(from: value).compactMap { Int($0) }.filter { $0 > 0 }
        }
    }
}
#endif
