import Foundation

public enum SearchHighlighter {
    public static func range(in content: String, matching text: SearchText) -> Range<Int>? {
        switch text {
        case .plain(let q):
            let lower = content.lowercased()
            guard let r = lower.range(of: q) else { return nil }
            let start = lower.distance(from: lower.startIndex, to: r.lowerBound)
            let length = lower.distance(from: r.lowerBound, to: r.upperBound)
            return start..<(start + length)
        case .jamo(let q):
            let (jamo, owner) = HangulIndexer.jamoWithOffsets(content)
            guard let r = jamo.range(of: q) else { return nil }
            let s = jamo.distance(from: jamo.startIndex, to: r.lowerBound)
            let e = jamo.distance(from: jamo.startIndex, to: r.upperBound)
            guard s < owner.count, e >= 1 else { return nil }
            return owner[s]..<(owner[e - 1] + 1)
        case .choseong(let q):
            // choseong()은 문자당 1:1 매핑이므로 초성열의 매치 구간이 곧 원문 구간
            let cs = HangulIndexer.choseong(content)
            guard let r = cs.range(of: q) else { return nil }
            let start = cs.distance(from: cs.startIndex, to: r.lowerBound)
            let length = cs.distance(from: r.lowerBound, to: r.upperBound)
            return start..<(start + length)
        }
    }
}
