import Foundation
import CoreGraphics

public enum PanelSide: String, Sendable {
    case left, right
}

public enum PanelFrame {
    public static func onScreen(visible: CGRect, side: PanelSide, width: CGFloat) -> CGRect {
        let x = side == .right ? visible.maxX - width : visible.minX
        return CGRect(x: x, y: visible.minY, width: width, height: visible.height)
    }

    public static func offScreen(visible: CGRect, side: PanelSide, width: CGFloat) -> CGRect {
        var frame = onScreen(visible: visible, side: side, width: width)
        frame.origin.x += side == .right ? width : -width
        return frame
    }
}
