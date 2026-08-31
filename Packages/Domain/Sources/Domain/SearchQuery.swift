import Foundation

public enum SearchText: Equatable, Sendable {
    case choseong(String)
    case jamo(String)
    case plain(String)
}

public struct SearchQuery: Equatable, Sendable {
    public let tags: [String]
    public let text: SearchText?

    public init(tags: [String], text: SearchText?) {
        self.tags = tags
        self.text = text
    }

    public static func parse(_ raw: String) -> SearchQuery {
        let tags = HashtagParser.tags(in: raw)
        let rest = raw.replacing(HashtagParser.tagPattern, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return SearchQuery(tags: tags, text: nil) }

        if HangulIndexer.isChoseongQuery(rest) {
            return SearchQuery(tags: tags, text: .choseong(rest))
        }
        if rest.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x3163).contains($0.value) }) {
            return SearchQuery(tags: tags, text: .jamo(HangulIndexer.jamo(rest)))
        }
        return SearchQuery(tags: tags, text: .plain(rest.lowercased()))
    }
}
