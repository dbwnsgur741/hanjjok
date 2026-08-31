import XCTest
@testable import PanelKit

final class PanelFrameTests: XCTestCase {
    // 메뉴바를 제외한 가시 영역을 흉내낸다 (1440x900 화면, 메뉴바 25pt)
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    // [v1.1] 플로팅 패널 — 상하 + 바깥쪽(화면 가장자리 쪽)에 기본 12pt 여백.
    // 안쪽 가장자리(슬라이드 방향)에는 별도 inset을 추가하지 않는다 — width는 그대로 유지.
    func test_오른쪽_패널_프레임() {
        let f = PanelFrame.onScreen(visible: visible, side: .right, width: 360)
        XCTAssertEqual(f, CGRect(x: 1068, y: 12, width: 360, height: 851))
    }
    func test_왼쪽_패널_프레임() {
        let f = PanelFrame.onScreen(visible: visible, side: .left, width: 360)
        XCTAssertEqual(f, CGRect(x: 12, y: 12, width: 360, height: 851))
    }
    func test_오른쪽_오프스크린은_화면_밖() {
        // offScreen은 onScreen과 같은 크기(width·height)로, 화면 가장자리에 딱 붙어 완전히 밖에 있다.
        let f = PanelFrame.offScreen(visible: visible, side: .right, width: 360)
        XCTAssertEqual(f, CGRect(x: 1440, y: 12, width: 360, height: 851))
    }
    func test_왼쪽_오프스크린은_화면_밖() {
        let f = PanelFrame.offScreen(visible: visible, side: .left, width: 360)
        XCTAssertEqual(f, CGRect(x: -360, y: 12, width: 360, height: 851))
    }

    // inset 매개변수 자체가 동작하는지 — 기본값(12)이 아닌 값을 넘겨 왼쪽/오른쪽 각 1개씩 확인.
    func test_커스텀_inset_오른쪽() {
        let f = PanelFrame.onScreen(visible: visible, side: .right, width: 360, inset: 20)
        XCTAssertEqual(f, CGRect(x: 1060, y: 20, width: 360, height: 835))
    }
    func test_커스텀_inset_왼쪽() {
        let f = PanelFrame.onScreen(visible: visible, side: .left, width: 360, inset: 20)
        XCTAssertEqual(f, CGRect(x: 20, y: 20, width: 360, height: 835))
    }
}
