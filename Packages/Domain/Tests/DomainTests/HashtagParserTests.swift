import XCTest
@testable import Domain

final class HashtagParserTests: XCTestCase {
    func test_기본_태그_추출() {
        XCTAssertEqual(HashtagParser.tags(in: "오늘 #업무 회의"), ["업무"])
    }
    func test_여러_태그_등장_순서_유지() {
        XCTAssertEqual(HashtagParser.tags(in: "#아이디어 메모 #업무"), ["아이디어", "업무"])
    }
    func test_문장부호에서_태그_종료() {
        XCTAssertEqual(HashtagParser.tags(in: "끝. #업무, 그리고 #회의!"), ["업무", "회의"])
    }
    func test_한영숫자_언더스코어_혼합_및_영문_소문자화() {
        XCTAssertEqual(HashtagParser.tags(in: "#일정_2026 #ProjectX"), ["일정_2026", "projectx"])
    }
    func test_중복_제거() {
        XCTAssertEqual(HashtagParser.tags(in: "#a #A 그리고 #a"), ["a"])
    }
    func test_샵_단독은_무시() {
        XCTAssertEqual(HashtagParser.tags(in: "# 그리고 #"), [])
    }
    func test_이모지는_태그_경계() {
        XCTAssertEqual(HashtagParser.tags(in: "#태그😀뒤"), ["태그"])
    }
    func test_단어_중간_샵도_인식() {
        // 정책: 위치 불문 # 뒤 유효 문자를 태그로 본다 (카톡 해시태그 습관과 동일)
        XCTAssertEqual(HashtagParser.tags(in: "회의록#업무"), ["업무"])
    }
    func test_조합_중_자모도_태그_문자로_허용() {
        XCTAssertEqual(HashtagParser.tags(in: "#메모ㅅ"), ["메모ㅅ"])
    }
}
