import SwiftUI
import AppKit
import PanelKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.space, modifiers: [.option]))
}

@main
struct HanjiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement 앱 — 보이는 기본 씬 없음
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private(set) var panelController: EdgePanelController!

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let sideRaw = UserDefaults.standard.string(forKey: "panelSide") ?? PanelSide.right.rawValue
        let side = PanelSide(rawValue: sideRaw) ?? .right
        let host = NSHostingView(rootView: PanelRootView())
        panelController = EdgePanelController(contentView: host, side: side, width: 360)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "paintbrush.pointed",
                                 accessibilityDescription: "한지")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            Task { @MainActor in self?.panelController.toggle() }
        }
    }

    @MainActor @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            panelController.toggle()
        }
    }

    @MainActor private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "전체 내보내기…", action: #selector(exportAll), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "한지 종료",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        menu.items.last?.target = NSApp
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // 좌클릭 토글을 되살리기 위해 즉시 해제
    }

    @objc func openSettings() { /* Task 14에서 구현 */ }
    @objc func exportAll() { /* Task 14에서 구현 */ }
}
