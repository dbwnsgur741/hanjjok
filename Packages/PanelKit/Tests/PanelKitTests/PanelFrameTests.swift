import XCTest
@testable import PanelKit

final class PanelFrameTests: XCTestCase {
    // 메뉴바를 제외한 가시 영역을 흉내낸다 (1440x900 화면, 메뉴바 25pt)
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    func test_오른쪽_패널_프레임() {
        let f = PanelFrame.onScreen(visible: visible, side: .right, width: 360)
        XCTAssertEqual(f, CGRect(x: 1080, y: 0, width: 360, height: 875))
    }
    func test_왼쪽_패널_프레임() {
        let f = PanelFrame.onScreen(visible: visible, side: .left, width: 360)
        XCTAssertEqual(f, CGRect(x: 0, y: 0, width: 360, height: 875))
    }
    func test_오른쪽_오프스크린은_화면_밖() {
        let f = PanelFrame.offScreen(visible: visible, side: .right, width: 360)
        XCTAssertEqual(f.origin.x, 1440)
    }
    func test_왼쪽_오프스크린은_화면_밖() {
        let f = PanelFrame.offScreen(visible: visible, side: .left, width: 360)
        XCTAssertEqual(f.origin.x, -360)
    }
}
