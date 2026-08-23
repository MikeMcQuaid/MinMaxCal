import Foundation

public struct TextLink: Hashable, Sendable {
    // MARK: Lifecycle

    public init(range: Range<String.Index>, url: URL) {
        self.range = range
        self.url = url
    }

    // MARK: Public

    public var range: Range<String.Index>
    public var url: URL
}
