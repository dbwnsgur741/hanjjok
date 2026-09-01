import AppKit

final class SlidePanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered, defer: false)
        self.contentView = contentView
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isMovable = false
        backgroundColor = .clear
        isOpaque = false
        // [v1.1] SwiftUI 쪽(PanelRootView)에서 라운드 클립 + 외부 그림자를 직접 그리므로
        // AppKit 네이티브 창 그림자는 끈다 — 둘 다 켜두면 그림자가 겹쳐 목업보다 짙게 보인다.
        hasShadow = false
    }

    // borderless 패널은 기본이 false — 키보드 입력을 받으려면 필수
    override var canBecomeKey: Bool { true }
}
