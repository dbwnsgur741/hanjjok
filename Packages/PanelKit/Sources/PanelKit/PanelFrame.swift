import Foundation
import CoreGraphics

public enum PanelSide: String, Sendable {
    case left, right
}

public enum PanelFrame {
    /// [v1.1] 플로팅 패널 — "벽에 붙은 판"이 아니라 "떠 있는 종이": 상하와 화면
    /// 바깥쪽 가장자리에 `inset`만큼 여백을 둔다. 슬라이드 방향인 안쪽 가장자리에는
    /// 별도 inset을 더하지 않는다 — width는 그대로 유지되고 프레임 전체가 안쪽으로
    /// 밀려 앉을 뿐이다.
    public static func onScreen(visible: CGRect, side: PanelSide, width: CGFloat, inset: CGFloat = 12) -> CGRect {
        let x = side == .right ? visible.maxX - width - inset : visible.minX + inset
        return CGRect(x: x, y: visible.minY + inset, width: width, height: visible.height - inset * 2)
    }

    /// onScreen과 같은 크기(width·height)로, 화면 가장자리에 딱 붙어 완전히 화면 밖에 위치한다.
    /// (inset은 쉬는 위치에만 적용되며, 오프스크린 시작 위치는 화면 경계 그대로다.)
    public static func offScreen(visible: CGRect, side: PanelSide, width: CGFloat, inset: CGFloat = 12) -> CGRect {
        let x = side == .right ? visible.maxX : visible.minX - width
        return CGRect(x: x, y: visible.minY + inset, width: width, height: visible.height - inset * 2)
    }
}
