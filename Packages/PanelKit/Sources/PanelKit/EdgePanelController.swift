import AppKit

@MainActor
public final class EdgePanelController {
    private let panel: SlidePanel
    private var previousApp: NSRunningApplication?

    public private(set) var isVisible = false
    public var onVisibilityChange: ((Bool) -> Void)?
    public var side: PanelSide
    public var width: CGFloat

    public init(contentView: NSView, side: PanelSide = .right, width: CGFloat = 360) {
        self.side = side
        self.width = width
        self.panel = SlidePanel(contentView: contentView)
    }

    public func toggle() {
        isVisible ? hide() : show()
    }

    public func show() {
        guard let screen = NSScreen.main else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        let visible = screen.visibleFrame
        panel.setFrame(PanelFrame.offScreen(visible: visible, side: side, width: width), display: false)
        panel.orderFrontRegardless()
        animate(to: PanelFrame.onScreen(visible: visible, side: side, width: width))
        panel.makeKey()
        isVisible = true
        onVisibilityChange?(true)
    }

    public func hide() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        animate(to: PanelFrame.offScreen(visible: visible, side: side, width: width)) { [weak self] in
            self?.panel.orderOut(nil)
        }
        isVisible = false
        onVisibilityChange?(false)
        previousApp?.activate()
        previousApp = nil
    }

    private func animate(to frame: NSRect, completion: (() -> Void)? = nil) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(frame, display: true)
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
        }, completionHandler: completion)
    }
}
