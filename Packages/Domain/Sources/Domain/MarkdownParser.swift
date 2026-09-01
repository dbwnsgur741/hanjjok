import Foundation

/// 마크다운 문서를 줄 단위 블록으로 분해한 결과.
/// 인라인 서식(`**굵게**` 등)은 뷰 계층의 `AttributedString(markdown:)`이 처리하므로
/// 여기서는 다루지 않는다 — QA r5-A(v1.3): 렌더링 토대인 블록 파서만 Domain에 둔다.
public enum MarkdownBlock: Equatable, Sendable {
    /// `#`~`###`. level 1~3, text는 마커·공백 제거 후 본문
    case heading(level: Int, text: String, lineRange: Range<Int>)
    /// `---`, `***`, `___`, 그리고 자동 대시 치환으로 생긴 `—` 3개 이상 연속
    case divider(lineRange: Range<Int>)
    /// 체크리스트 — item은 ChecklistParser가 만든 값 그대로(토글에 그대로 넘길 수 있어야 함)
    case checklist(item: ChecklistItem)
    /// `- ` / `* ` 불릿 (체크리스트가 아닌 경우에만)
    case bullet(text: String, lineRange: Range<Int>)
    /// `> ` 인용
    case quote(text: String, lineRange: Range<Int>)
    /// 그 외 모든 줄(빈 줄 포함)
    case paragraph(text: String, lineRange: Range<Int>)
}

public enum MarkdownParser {
    /// 제목: `#`~`###` + 공백 1개 이상 + 본문. `####`(4개 이상)나 공백 없는 `#`는 매치되지 않아
    /// 문단으로 떨어진다.
    private static let headingRegex = #/^(#{1,3}) +(.*)$/#

    /// 불릿: 선행 공백 허용, `-`·`*` + 공백 1개 이상 + 본문 1자 이상. 본문이 비면(`- `만)
    /// 매치되지 않아 문단으로 떨어진다(연속 종료 신호는 r5-C가 별도 처리).
    private static let bulletRegex = #/^ *[-*] +(.+)$/#

    /// 인용: `>` 뒤 공백은 선택, 본문은 없어도(빈 문자열) 매치된다.
    private static let quoteRegex = #/^ *> ?(.*)$/#

    /// 줄 단위 블록 분해. lineRange는 ChecklistParser와 동일 규칙 —
    /// content 전체 기준 Character 오프셋, 개행 제외.
    /// 줄 분할 자체도 ChecklistParser.items(in:)와 완전히 동일한 로직을 사용해야
    /// 렌더러가 두 파서의 오프셋을 같은 축에서 다룰 수 있다.
    public static func blocks(in content: String) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var offset = 0
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let count = line.count
            let range = offset..<(offset + count)
            result.append(block(for: String(line), range: range))
            offset += count + 1  // "\n" 몫
        }
        return result
    }

    /// 판정 우선순위: 체크리스트 → 제목 → 구분선 → 불릿 → 인용 → 문단.
    /// 체크리스트를 먼저 봐야 `- [ ] 할일`이 불릿으로 오인되지 않는다.
    private static func block(for line: String, range: Range<Int>) -> MarkdownBlock {
        // 체크리스트 판정은 반드시 ChecklistParser를 재사용한다(정규식 중복 금지).
        // items(in:)는 단일 줄 입력에 대해 lineRange를 줄 내부 기준(0..<줄길이)으로
        // 돌려주므로, content 전체 기준 오프셋(range.lowerBound)을 더해 다시 담는다.
        // 이 값이 그대로 토글에 쓰이므로 정확해야 한다.
        if let checklistItem = ChecklistParser.items(in: line).first {
            let rebased = ChecklistItem(
                lineRange: (range.lowerBound + checklistItem.lineRange.lowerBound)
                    ..< (range.lowerBound + checklistItem.lineRange.upperBound),
                isChecked: checklistItem.isChecked,
                text: checklistItem.text
            )
            return .checklist(item: rebased)
        }

        if let match = line.wholeMatch(of: headingRegex) {
            return .heading(level: match.output.1.count, text: String(match.output.2), lineRange: range)
        }

        if isDivider(line) {
            return .divider(lineRange: range)
        }

        if let match = line.wholeMatch(of: bulletRegex) {
            return .bullet(text: String(match.output.1), lineRange: range)
        }

        if let match = line.wholeMatch(of: quoteRegex) {
            return .quote(text: String(match.output.1), lineRange: range)
        }

        return .paragraph(text: line, lineRange: range)
    }

    /// 구분선: 트림 후 `-`/`*`/`_`/`—`(U+2014) 중 한 문자만 3개 이상 반복.
    /// `--`(2개)처럼 3개 미만이거나, 서로 다른 문자가 섞이면 구분선이 아니다.
    private static func isDivider(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, let first = trimmed.first else { return false }
        guard first == "-" || first == "*" || first == "_" || first == "—" else { return false }
        return trimmed.allSatisfy { $0 == first }
    }
}
