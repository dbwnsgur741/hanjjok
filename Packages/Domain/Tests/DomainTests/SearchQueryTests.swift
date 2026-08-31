import XCTest
@testable import Domain

final class SearchQueryTests: XCTestCase {
    func test_초성만_질의() {
        XCTAssertEqual(SearchQuery.parse("ㅅㄴ"), SearchQuery(tags: [], text: .choseong("ㅅㄴ")))
    }
    func test_초성_질의는_양끝_공백만_정리하고_내부_공백_보존() {
        XCTAssertEqual(SearchQuery.parse(" ㅅㅊ ㄴㅇ "), SearchQuery(tags: [], text: .choseong("ㅅㅊ ㄴㅇ")))
    }
    func test_한글_일반_질의는_자모로() {
        XCTAssertEqual(SearchQuery.parse("회의"), SearchQuery(tags: [], text: .jamo("ㅎㅗㅣㅇㅡㅣ")))
    }
    func test_조합_중_질의도_자모로() {
        XCTAssertEqual(SearchQuery.parse("사이ㄷ"), SearchQuery(tags: [], text: .jamo("ㅅㅏㅇㅣㄷ")))
    }
    func test_영문_질의는_소문자_plain() {
        XCTAssertEqual(SearchQuery.parse("Memo"), SearchQuery(tags: [], text: .plain("memo")))
    }
    func test_태그와_텍스트_결합() {
        XCTAssertEqual(SearchQuery.parse("#업무 회의"),
                       SearchQuery(tags: ["업무"], text: .jamo("ㅎㅗㅣㅇㅡㅣ")))
    }
    func test_태그만_있으면_텍스트는_nil() {
        XCTAssertEqual(SearchQuery.parse("#업무"), SearchQuery(tags: ["업무"], text: nil))
    }
    func test_빈_질의() {
        XCTAssertEqual(SearchQuery.parse("  "), SearchQuery(tags: [], text: nil))
    }
}
