import SwiftUI
import AppKit
import PanelKit
import KeyboardShortcuts
import Domain
import Data

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
    // Task 14의 내보내기가 사용
    private(set) var repo: GRDBNoteRepository!
    private(set) var model: TimelineModel!
    private var settingsWindow: NSWindow?
    private var defaultsObserver: NSObjectProtocol?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hanji")
        do {
            repo = try GRDBNoteRepository(databaseURL: appSupport.appendingPathComponent("hanji.sqlite"))
            try BackupScheduler.runIfNeeded(
                repository: repo, backupsDir: appSupport.appendingPathComponent("Backups"))
        } catch {
            fatalError("데이터베이스 초기화 실패: \(error)")
        }
        model = TimelineModel(repo: repo)

        let side = currentPanelSide()
        let width = currentPanelWidth()
        let host = NSHostingView(rootView: PanelRootView(model: model))
        panelController = EdgePanelController(contentView: host, side: side, width: width)

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

        // 설정 창에서 패널 위치/폭을 바꾸면 다음 show()가 아니라 즉시 반영되도록 구독한다.
        // (SettingsView는 @AppStorage로 UserDefaults에 바로 쓰므로 이 알림이 항상 뒤따른다.)
        // UserDefaults.didChangeNotification은 이 두 키뿐 아니라 단축키 녹화·글꼴 토글 등
        // 모든 defaults 변경에도 발동하므로, 실제로 값이 바뀐 경우에만 대입한다 — panelController가
        // 매번 무조건 갱신되면(변경 없음에도) 불필요한 쓰기가 반복된다.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let side = self.currentPanelSide()
            if self.panelController.side.rawValue != side.rawValue { self.panelController.side = side }
            let width = self.currentPanelWidth()
            if self.panelController.width != width { self.panelController.width = width }
        }
    }

    private func currentPanelSide() -> PanelSide {
        let raw = UserDefaults.standard.string(forKey: "panelSide") ?? PanelSide.right.rawValue
        return PanelSide(rawValue: raw) ?? .right
    }

    private func currentPanelWidth() -> CGFloat {
        let stored = UserDefaults.standard.double(forKey: "panelWidth")
        return stored > 0 ? stored : 360
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

    @MainActor @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "한지 설정"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.center()
    }

    @MainActor @objc func exportAll() {
        Task {
            do {
                let notes = try await self.repo.exportAll()
                let markdown = MarkdownExporter.export(notes)
                let panel = NSSavePanel()
                panel.nameFieldStringValue = "hanji-export.md"
                // LSUIElement 앱은 Dock 아이콘이 없어 활성화하지 않으면 저장 패널이 키 윈도우가
                // 되지 않을 수 있다 — 반드시 runModal() 전에 활성화한다.
                NSApp.activate(ignoringOtherApps: true)
                if panel.runModal() == .OK, let url = panel.url {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                self.showExportError(error)
            }
        }
    }

    @MainActor private func showExportError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "내보내기에 실패했습니다"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
