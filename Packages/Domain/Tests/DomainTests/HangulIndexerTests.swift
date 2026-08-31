import XCTest
@testable import Domain

final class HangulIndexerTests: XCTestCase {
    // 자모 분해
    func test_기본_음절_분해() {
        XCTAssertEqual(HangulIndexer.jamo("사이드"), "ㅅㅏㅇㅣㄷㅡ")
    }
    func test_겹받침_분해() {
        XCTAssertEqual(HangulIndexer.jamo("닭"), "ㄷㅏㄹㄱ")
    }
    func test_복합_모음_분해() {
        XCTAssertEqual(HangulIndexer.jamo("왜"), "ㅇㅗㅐ")
    }
    func test_한영숫자_혼합() {
        XCTAssertEqual(HangulIndexer.jamo("Memo 2번"), "memo 2ㅂㅓㄴ")
    }
    func test_단독_겹자모도_분해() {
        XCTAssertEqual(HangulIndexer.jamo("ㄳ"), "ㄱㅅ")
        XCTAssertEqual(HangulIndexer.jamo("ㅢ"), "ㅡㅣ")
    }
    func test_조합_중_입력은_완성형의_접두사() {
        // "사이드"를 타이핑하는 도중 상태 "사이ㄷ"의 자모열은 완성형 자모열의 접두사여야 한다
        XCTAssertTrue(HangulIndexer.jamo("사이드").hasPrefix(HangulIndexer.jamo("사이ㄷ")))
        // "사과" 타이핑 도중 "사고" 상태도 접두사 관계 유지 (ㅗ → ㅘ 조합)
        XCTAssertTrue(HangulIndexer.jamo("사과").hasPrefix(HangulIndexer.jamo("사고")))
    }
    // 오프셋
    func test_오프셋_매핑() {
        let (jamo, owner) = HangulIndexer.jamoWithOffsets("사이드")
        XCTAssertEqual(jamo, "ㅅㅏㅇㅣㄷㅡ")
        XCTAssertEqual(owner, [0, 0, 1, 1, 2, 2])
    }
    func test_오프셋_겹받침() {
        let (jamo, owner) = HangulIndexer.jamoWithOffsets("닭장")
        XCTAssertEqual(jamo, "ㄷㅏㄹㄱㅈㅏㅇ")
        XCTAssertEqual(owner, [0, 0, 0, 0, 1, 1, 1])
    }
    // 초성
    func test_초성_추출() {
        XCTAssertEqual(HangulIndexer.choseong("사이드노트"), "ㅅㅇㄷㄴㅌ")
    }
    func test_초성_비한글_보존_길이_동일() {
        let text = "메모 2번 Ok"
        XCTAssertEqual(HangulIndexer.choseong(text), "ㅁㅁ 2ㅂ ok")
        XCTAssertEqual(HangulIndexer.choseong(text).count, text.count)
    }
    // 초성 질의 판별
    func test_초성_질의_판별() {
        XCTAssertTrue(HangulIndexer.isChoseongQuery("ㅅㄴ"))
        XCTAssertTrue(HangulIndexer.isChoseongQuery("ㅅㅊ ㄴㅇ"))   // 공백 허용
        XCTAssertFalse(HangulIndexer.isChoseongQuery("사ㄴ"))       // 음절 섞임
        XCTAssertFalse(HangulIndexer.isChoseongQuery("ㅏㅓ"))       // 모음은 초성 아님
        XCTAssertFalse(HangulIndexer.isChoseongQuery("sn"))
        XCTAssertFalse(HangulIndexer.isChoseongQuery("   "))
    }
}
