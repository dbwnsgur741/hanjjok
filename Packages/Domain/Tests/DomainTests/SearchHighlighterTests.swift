import XCTest
@testable import Domain

final class SearchHighlighterTests: XCTestCase {
    func test_plain_매치_구간() {
        XCTAssertEqual(SearchHighlighter.range(in: "오늘 Memo 정리", matching: .plain("memo")), 3..<7)
    }
    func test_jamo_매치_구간은_원문_문자_단위() {
        // "사이ㄷ"(자모 ㅅㅏㅇㅣㄷ)는 "사이드"의 세 글자 전체를 하이라이트
        XCTAssertEqual(SearchHighlighter.range(in: "메모 사이드", matching: .jamo("ㅅㅏㅇㅣㄷ")), 3..<6)
    }
    func test_choseong_매치_구간() {
        XCTAssertEqual(SearchHighlighter.range(in: "어제 노트 정리", matching: .choseong("ㄴㅌ")), 3..<5)
    }
    func test_매치_없으면_nil() {
        XCTAssertNil(SearchHighlighter.range(in: "메모", matching: .plain("xyz")))
        XCTAssertNil(SearchHighlighter.range(in: "메모", matching: .choseong("ㅋㅋ")))
    }
}
