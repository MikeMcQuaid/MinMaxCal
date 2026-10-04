extension SyncWrite: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action.rawValue, forKey: .action)
        try container.encode(reasons, forKey: .reasons)
        try container.encode(link, forKey: .link)
        switch self {
        case let .remove(_, target, _):
            try container.encode(target, forKey: .target)

        case let .save(_, source, target, content):
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(target, forKey: .target)
            try container.encode(content, forKey: .proposedContent)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case action
        case link
        case proposedContent
        case reasons
        case source
        case target
    }
}
