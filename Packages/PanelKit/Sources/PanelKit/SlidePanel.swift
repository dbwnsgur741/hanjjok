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
        hasShadow = true
    }

    // borderless 패널은 기본이 false — 키보드 입력을 받으려면 필수
    override var canBecomeKey: Bool { true }
}
