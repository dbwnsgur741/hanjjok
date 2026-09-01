import XCTest
@testable import Domain

final class ChecklistParserTests: XCTestCase {

    // MARK: - items(in:) 기본 케이스

    func test_기본_체크_없음() {
        let content = "[] 리뷰 답변"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].isChecked, false)
        XCTAssertEqual(items[0].text, "리뷰 답변")
    }

    func test_체크됨_소문자_x() {
        let content = "- [x] 배포"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].isChecked, true)
        XCTAssertEqual(items[0].text, "배포")
    }

    func test_체크됨_대문자_X() {
        let content = "[X] 배포"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].isChecked, true)
        XCTAssertEqual(items[0].text, "배포")
    }

    func test_빈_텍스트() {
        let content = "[ ]"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].isChecked, false)
        XCTAssertEqual(items[0].text, "")
    }

    // MARK: - 마커 형식 검증 (wholeMatch)

    func test_공백_없이_붙어있으면_항목_아님() {
        let content = "[]abc"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 0)
    }

    func test_문장_중간의_체크박스는_항목_아님() {
        let content = "좌표 [x] 표"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 0)
    }

    // MARK: - lineRange 오프셋 정확성

    func test_단일_줄_lineRange() {
        let content = "[] 항목"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        // lineRange는 개행 제외한 Character 오프셋
        let sliced = String(content[content.index(content.startIndex, offsetBy: items[0].lineRange.lowerBound)..<content.index(content.startIndex, offsetBy: items[0].lineRange.upperBound)])
        XCTAssertEqual(sliced, "[] 항목")
    }

    func test_여러_줄_lineRange_오프셋() {
        let content = "제목\n[] 하나\n본문\n[x] 둘"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 2)

        // 첫 번째 항목 검증
        let line1 = String(content[content.index(content.startIndex, offsetBy: items[0].lineRange.lowerBound)..<content.index(content.startIndex, offsetBy: items[0].lineRange.upperBound)])
        XCTAssertEqual(line1, "[] 하나")
        XCTAssertEqual(items[0].isChecked, false)
        XCTAssertEqual(items[0].text, "하나")

        // 두 번째 항목 검증
        let line2 = String(content[content.index(content.startIndex, offsetBy: items[1].lineRange.lowerBound)..<content.index(content.startIndex, offsetBy: items[1].lineRange.upperBound)])
        XCTAssertEqual(line2, "[x] 둘")
        XCTAssertEqual(items[1].isChecked, true)
        XCTAssertEqual(items[1].text, "둘")
    }

    func test_선행_공백_포함_lineRange() {
        let content = "  [ ] 들여쓰기"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        let sliced = String(content[content.index(content.startIndex, offsetBy: items[0].lineRange.lowerBound)..<content.index(content.startIndex, offsetBy: items[0].lineRange.upperBound)])
        XCTAssertEqual(sliced, "  [ ] 들여쓰기")
    }

    // MARK: - toggling(_:at:)

    func test_빈_체크박스를_체크로_변경() {
        let content = "[] 항목"
        let items = ChecklistParser.items(in: content)
        let toggled = ChecklistParser.toggling(content, at: items[0])
        XCTAssertEqual(toggled, "[x] 항목")
    }

    func test_공백_체크박스를_체크로_변경() {
        let content = "[ ] 항목"
        let items = ChecklistParser.items(in: content)
        let toggled = ChecklistParser.toggling(content, at: items[0])
        XCTAssertEqual(toggled, "[x] 항목")
    }

    func test_소문자x_체크박스를_미체크로_변경() {
        let content = "[x] 항목"
        let items = ChecklistParser.items(in: content)
        let toggled = ChecklistParser.toggling(content, at: items[0])
        XCTAssertEqual(toggled, "[ ] 항목")
    }

    func test_대문자X_체크박스를_미체크로_변경() {
        let content = "[X] 항목"
        let items = ChecklistParser.items(in: content)
        let toggled = ChecklistParser.toggling(content, at: items[0])
        XCTAssertEqual(toggled, "[ ] 항목")
    }

    func test_하이픈_접두_보존() {
        let content = "- [ ] 항목"
        let items = ChecklistParser.items(in: content)
        let toggled = ChecklistParser.toggling(content, at: items[0])
        XCTAssertEqual(toggled, "- [x] 항목")
    }

    func test_선행_공백_보존() {
        let content = "  [ ] 들여쓰기"
        let items = ChecklistParser.items(in: content)
        let toggled = ChecklistParser.toggling(content, at: items[0])
        XCTAssertEqual(toggled, "  [x] 들여쓰기")
    }

    func test_여러_줄에서_특정_항목_토글() {
        let content = "[ ] 첫째\n[x] 둘째\n[ ] 셋째"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 3)

        let toggled = ChecklistParser.toggling(content, at: items[1])
        XCTAssertEqual(toggled, "[ ] 첫째\n[ ] 둘째\n[ ] 셋째")
    }

    func test_어긋난_lineRange_원본_반환() {
        let content = "[ ] 항목"
        var item = ChecklistParser.items(in: content)[0]
        // lineRange를 잘못된 값으로 변경
        item = ChecklistItem(lineRange: 0..<100, isChecked: false, text: "항목")
        let toggled = ChecklistParser.toggling(content, at: item)
        XCTAssertEqual(toggled, content)
    }

    func test_내용_변경된_lineRange_원본_반환() {
        let content = "[ ] 원래"
        var item = ChecklistParser.items(in: content)[0]
        // 다른 text를 갖는 item으로 수정
        item = ChecklistItem(lineRange: item.lineRange, isChecked: false, text: "다른")
        let toggled = ChecklistParser.toggling(content, at: item)
        XCTAssertEqual(toggled, content)
    }

    // MARK: - progress(in:)

    func test_진행_상황_1_out_of_2() {
        let content = "[x] 완료\n[ ] 미완료"
        let progress = ChecklistParser.progress(in: content)
        XCTAssertEqual(progress.checked, 1)
        XCTAssertEqual(progress.total, 2)
    }

    func test_진행_상황_0_out_of_0() {
        let content = "항목 없음"
        let progress = ChecklistParser.progress(in: content)
        XCTAssertEqual(progress.checked, 0)
        XCTAssertEqual(progress.total, 0)
    }

    func test_진행_상황_모두_완료() {
        let content = "[x] 첫째\n[x] 둘째\n[x] 셋째"
        let progress = ChecklistParser.progress(in: content)
        XCTAssertEqual(progress.checked, 3)
        XCTAssertEqual(progress.total, 3)
    }

    func test_진행_상황_모두_미완료() {
        let content = "[ ] 첫째\n[ ] 둘째"
        let progress = ChecklistParser.progress(in: content)
        XCTAssertEqual(progress.checked, 0)
        XCTAssertEqual(progress.total, 2)
    }

    // MARK: - 추가 엣지 케이스

    func test_빈_내용() {
        let content = ""
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 0)
    }

    func test_체크박스_없는_줄들() {
        let content = "첫째 줄\n둘째 줄\n셋째 줄"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 0)
    }

    func test_혼합된_줄들() {
        let content = "일반 텍스트\n[ ] 항목 1\n또 다른 텍스트\n[x] 항목 2"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].text, "항목 1")
        XCTAssertEqual(items[1].text, "항목 2")
    }

    func test_한글_텍스트_처리() {
        let content = "[] 한글 테스트\n[x] 또 다른 한글"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].text, "한글 테스트")
        XCTAssertEqual(items[1].text, "또 다른 한글")
    }

    func test_뒷_줄에_개행() {
        let content = "[ ] 마지막 항목\n"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].text, "마지막 항목")
    }

    func test_여러_개행() {
        let content = "[ ] 첫째\n\n[ ] 둘째"
        let items = ChecklistParser.items(in: content)
        XCTAssertEqual(items.count, 2)
    }

    func test_하이픈_공백_접두_다양한_조합() {
        let items1 = ChecklistParser.items(in: "[ ] 항목")
        let items2 = ChecklistParser.items(in: "- [ ] 항목")
        let items3 = ChecklistParser.items(in: "  [ ] 항목")
        let items4 = ChecklistParser.items(in: "  - [ ] 항목")

        XCTAssertEqual(items1.count, 1)
        XCTAssertEqual(items2.count, 1)
        XCTAssertEqual(items3.count, 1)
        XCTAssertEqual(items4.count, 1)
    }
}
