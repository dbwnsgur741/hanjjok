import XCTest
@testable import Domain

final class MarkdownParserTests: XCTestCase {

    // MARK: - 제목

    func test_제목_레벨1() {
        let blocks = MarkdownParser.blocks(in: "# 제목")
        XCTAssertEqual(blocks.count, 1)
        guard case .heading(let level, let text, let range) = blocks[0] else {
            return XCTFail("heading이어야 함: \(blocks[0])")
        }
        XCTAssertEqual(level, 1)
        XCTAssertEqual(text, "제목")
        XCTAssertEqual(range, 0..<4)
    }

    func test_제목_레벨2() {
        let blocks = MarkdownParser.blocks(in: "## 소제목")
        guard case .heading(let level, let text, _) = blocks[0] else {
            return XCTFail("heading이어야 함: \(blocks[0])")
        }
        XCTAssertEqual(level, 2)
        XCTAssertEqual(text, "소제목")
    }

    func test_제목_레벨3() {
        let blocks = MarkdownParser.blocks(in: "### 소소제목")
        guard case .heading(let level, let text, _) = blocks[0] else {
            return XCTFail("heading이어야 함: \(blocks[0])")
        }
        XCTAssertEqual(level, 3)
        XCTAssertEqual(text, "소소제목")
    }

    func test_샵4개는_문단() {
        let blocks = MarkdownParser.blocks(in: "#### 제목아님")
        guard case .paragraph(let text, _) = blocks[0] else {
            return XCTFail("paragraph여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "#### 제목아님")
    }

    func test_샵만_있고_공백없음은_문단() {
        let blocks = MarkdownParser.blocks(in: "#제목아님")
        guard case .paragraph(let text, _) = blocks[0] else {
            return XCTFail("paragraph여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "#제목아님")
    }

    // MARK: - 구분선

    func test_구분선_하이픈() {
        let blocks = MarkdownParser.blocks(in: "---")
        guard case .divider = blocks[0] else {
            return XCTFail("divider여야 함: \(blocks[0])")
        }
    }

    func test_구분선_별표() {
        let blocks = MarkdownParser.blocks(in: "***")
        guard case .divider = blocks[0] else {
            return XCTFail("divider여야 함: \(blocks[0])")
        }
    }

    func test_구분선_언더스코어() {
        let blocks = MarkdownParser.blocks(in: "___")
        guard case .divider = blocks[0] else {
            return XCTFail("divider여야 함: \(blocks[0])")
        }
    }

    func test_구분선_엠대시_세개() {
        let blocks = MarkdownParser.blocks(in: "———")
        guard case .divider = blocks[0] else {
            return XCTFail("divider여야 함: \(blocks[0])")
        }
    }

    func test_하이픈_두개는_문단() {
        let blocks = MarkdownParser.blocks(in: "--")
        guard case .paragraph(let text, _) = blocks[0] else {
            return XCTFail("paragraph여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "--")
    }

    // MARK: - 체크리스트 vs 불릿 vs 문단

    func test_체크리스트_하이픈_대괄호_공백() {
        let blocks = MarkdownParser.blocks(in: "- [ ] 할일")
        guard case .checklist(let item) = blocks[0] else {
            return XCTFail("checklist여야 함(불릿 아님): \(blocks[0])")
        }
        XCTAssertEqual(item.isChecked, false)
        XCTAssertEqual(item.text, "할일")
    }

    func test_체크리스트_공백없는_대괄호() {
        let blocks = MarkdownParser.blocks(in: "[]할일")
        guard case .checklist(let item) = blocks[0] else {
            return XCTFail("checklist여야 함: \(blocks[0])")
        }
        XCTAssertEqual(item.isChecked, false)
        XCTAssertEqual(item.text, "할일")
    }

    func test_불릿() {
        let blocks = MarkdownParser.blocks(in: "- 항목")
        guard case .bullet(let text, _) = blocks[0] else {
            return XCTFail("bullet이어야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "항목")
    }

    func test_하이픈_공백만은_문단() {
        let blocks = MarkdownParser.blocks(in: "- ")
        guard case .paragraph(let text, _) = blocks[0] else {
            return XCTFail("paragraph여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "- ")
    }

    // MARK: - 인용

    func test_인용_본문있음() {
        let blocks = MarkdownParser.blocks(in: "> 인용")
        guard case .quote(let text, _) = blocks[0] else {
            return XCTFail("quote여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "인용")
    }

    func test_인용_본문없음() {
        let blocks = MarkdownParser.blocks(in: ">")
        guard case .quote(let text, _) = blocks[0] else {
            return XCTFail("quote여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "")
    }

    // MARK: - 혼합 문서 lineRange 정확성

    func test_혼합_문서_lineRange_슬라이스_일치() {
        let content = "# 제목\n- [ ] 할일\n- 불릿\n> 인용\n---\n일반 문단"
        let blocks = MarkdownParser.blocks(in: content)
        XCTAssertEqual(blocks.count, 6)

        let chars = Array(content)
        func slice(_ range: Range<Int>) -> String {
            String(chars[range])
        }

        for block in blocks {
            switch block {
            case .heading(_, _, let range):
                XCTAssertEqual(slice(range), "# 제목")
            case .divider(let range):
                XCTAssertEqual(slice(range), "---")
            case .checklist(let item):
                XCTAssertEqual(slice(item.lineRange), "- [ ] 할일")
            case .bullet(_, let range):
                XCTAssertEqual(slice(range), "- 불릿")
            case .quote(_, let range):
                XCTAssertEqual(slice(range), "> 인용")
            case .paragraph(_, let range):
                XCTAssertEqual(slice(range), "일반 문단")
            }
        }
    }

    // MARK: - 체크리스트 오프셋 회귀 (핵심 케이스)

    func test_체크리스트_오프셋_회귀_토글이_의도한_줄만_바꿈() {
        let content = "제목\n- [ ] 하나\n본문\n- [x] 둘"
        let blocks = MarkdownParser.blocks(in: content)

        var checklistItems: [ChecklistItem] = []
        for block in blocks {
            if case .checklist(let item) = block {
                checklistItems.append(item)
            }
        }
        XCTAssertEqual(checklistItems.count, 2)
        XCTAssertEqual(checklistItems[0].isChecked, false)
        XCTAssertEqual(checklistItems[0].text, "하나")
        XCTAssertEqual(checklistItems[1].isChecked, true)
        XCTAssertEqual(checklistItems[1].text, "둘")

        // 첫 번째 항목만 토글 → 두 번째 줄만 바뀌고 나머지는 그대로
        let toggledFirst = ChecklistParser.toggling(content, at: checklistItems[0])
        XCTAssertEqual(toggledFirst, "제목\n- [x] 하나\n본문\n- [x] 둘")

        // 두 번째 항목만 토글 → 네 번째 줄만 바뀌고 나머지는 그대로
        let toggledSecond = ChecklistParser.toggling(content, at: checklistItems[1])
        XCTAssertEqual(toggledSecond, "제목\n- [ ] 하나\n본문\n- [ ] 둘")
    }

    // MARK: - 빈 문자열 / 개행만

    func test_빈_문자열은_문단_하나() {
        let blocks = MarkdownParser.blocks(in: "")
        XCTAssertEqual(blocks.count, 1)
        guard case .paragraph(let text, let range) = blocks[0] else {
            return XCTFail("paragraph여야 함: \(blocks[0])")
        }
        XCTAssertEqual(text, "")
        XCTAssertEqual(range, 0..<0)
    }

    func test_개행만_있으면_문단_여러개() {
        let blocks = MarkdownParser.blocks(in: "\n\n")
        XCTAssertEqual(blocks.count, 3)
        for block in blocks {
            guard case .paragraph(let text, _) = block else {
                return XCTFail("paragraph여야 함: \(block)")
            }
            XCTAssertEqual(text, "")
        }
    }
}
