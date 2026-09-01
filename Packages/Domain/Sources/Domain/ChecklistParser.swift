import Foundation

/// 체크리스트 항목의 단일 줄을 표현한다.
public struct ChecklistItem: Equatable, Sendable {
    /// content 전체에서 이 항목의 "줄"이 차지하는 Character 오프셋 범위 (개행 제외)
    public let lineRange: Range<Int>
    /// 체크 여부
    public let isChecked: Bool
    /// 마커 뒤 본문 (마커와 구분 공백 1개 제외, 이후는 그대로)
    public let text: String

    public init(lineRange: Range<Int>, isChecked: Bool, text: String) {
        self.lineRange = lineRange
        self.isChecked = isChecked
        self.text = text
    }
}

public enum ChecklistParser {
    /// 줄 규칙: 선행 공백 허용, `-`·`*` 접두 허용(뒤 공백 선택), `[]`·`[ ]`·`[x]`·`[X]` 마커,
    /// 마커 뒤 공백도 선택(있어도 없어도 무방) + 본문. `[]abc`처럼 마커 뒤에 공백 없이 붙어도
    /// 항목으로 인식한다(QA r2 근거: `[]할일`이 인식 안 되는 사용자 피드백으로 완화).
    private static let lineRegex = #/^\s*(?:[-*] ?)?\[(?<mark>[ xX]?)\] ?(?<text>.*)$/#

    public static func items(in content: String) -> [ChecklistItem] {
        var result: [ChecklistItem] = []
        var offset = 0
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let count = line.count
            if let parsed = parseLine(String(line)) {
                result.append(ChecklistItem(
                    lineRange: offset..<(offset + count),
                    isChecked: parsed.isChecked,
                    text: parsed.text))
            }
            offset += count + 1  // "\n" 몫
        }
        return result
    }

    private static func parseLine(_ line: String) -> (isChecked: Bool, text: String)? {
        guard let match = line.wholeMatch(of: lineRegex) else { return nil }
        let mark = match.output.mark
        return (mark == "x" || mark == "X", String(match.output.text))
    }

    /// 괄호 안만 바꾼 새 content: `[]`·`[ ]`→`[x]`, `[x]`·`[X]`→`[ ]`.
    /// lineRange가 현재 content와 어긋나 있으면(그 사이 편집됨) 원본을 그대로 돌려준다.
    public static func toggling(_ content: String, at item: ChecklistItem) -> String {
        let chars = Array(content)
        guard item.lineRange.upperBound <= chars.count else { return content }
        let line = String(chars[item.lineRange.lowerBound..<item.lineRange.upperBound])
        guard let parsed = parseLine(line),
              parsed.isChecked == item.isChecked, parsed.text == item.text,
              let open = line.firstIndex(of: "["),
              let close = line.firstIndex(of: "]") else { return content }
        let newLine = String(line[line.startIndex...open])
            + (item.isChecked ? " " : "x")
            + String(line[close...])
        var out = chars
        out.replaceSubrange(item.lineRange.lowerBound..<item.lineRange.upperBound,
                            with: Array(newLine))
        return String(out)
    }

    /// 현재 content의 체크리스트 진행 상황을 반환한다.
    public static func progress(in content: String) -> (checked: Int, total: Int) {
        let all = items(in: content)
        return (all.filter(\.isChecked).count, all.count)
    }
}
