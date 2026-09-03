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
struct HanjjokApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement 앱 — 보이는 기본 씬 없음
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private(set) var panelController: EdgePanelController!
    private var hostView: NSView?
    // Task 14의 내보내기가 사용
    private(set) var repo: GRDBNoteRepository!
    private(set) var model: TimelineModel!
    private var settingsWindow: NSWindow?
    private var defaultsObserver: NSObjectProtocol?
    // [Task 24] applyAppearance()의 값 비교 가드가 쓰는 마지막 적용값 — defaultsObserver가
    // 단축키 녹화·글꼴 토글 등 무관한 defaults 변경에도 매번 발동하므로, 실제로 모드 문자열이
    // 달라졌을 때만 NSApp.appearance를 다시 대입한다(패널 위치/폭과 같은 관례, Task 14 리뷰 지적 이월).
    private var lastAppliedAppearance: String?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hanjjok")
        do {
            repo = try GRDBNoteRepository(databaseURL: appSupport.appendingPathComponent("hanjjok.sqlite"))
            try BackupScheduler.runIfNeeded(
                repository: repo, backupsDir: appSupport.appendingPathComponent("Backups"))
        } catch {
            fatalError("데이터베이스 초기화 실패: \(error)")
        }
        model = TimelineModel(repo: repo)

        let side = currentPanelSide()
        let width = currentPanelWidth()
        // [Task 24] TimelineView가 직접 NSApp.delegate를 캐스팅해 openSettings()를 부르던
        // 배선은 SwiftUI 수명주기에서 NSApp.delegate가 내부 델리게이트라 항상 nil이 되어
        // 설정 버튼이 무반응이었다(실사용 버그) — PanelRootView에 클로저로 직접 주입한다.
        let host = NSHostingView(
            rootView: PanelRootView(
                model: model,
                onOpenSettings: { [weak self] in self?.openSettings() },
                // panelController는 이 줄 다음에 할당되지만, 클로저는 Esc 시점에 지연 평가되므로 안전하다.
                onRequestHide: { [weak self] in self?.panelController.hide() }))
        panelController = EdgePanelController(contentView: host, side: side, width: width)
        hostView = host
        applyAppearance()
        #if DEBUG
        installSnapshotHookIfRequested()
        #endif

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "paintbrush.pointed",
                                 accessibilityDescription: "한쪽")
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
            self.applyAppearance()
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

    /// [Task 24] 화면 모드 — SettingsView의 Picker("화면 모드")가 "system"/"light"/"dark"로
    /// appearanceMode에 쓰면, defaultsObserver를 거쳐 여기서 NSApp.appearance에 즉시 반영한다.
    /// 마지막으로 적용한 문자열과 같으면 재대입하지 않는다(panelSide/panelWidth와 동일한
    /// 값 비교 가드 관례 — 무관한 defaults 변경마다 appearance를 다시 쓰지 않기 위함).
    @MainActor private func applyAppearance() {
        let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        guard mode != lastAppliedAppearance else { return }
        lastAppliedAppearance = mode
        switch mode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
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
        menu.addItem(withTitle: "한쪽 종료",
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
            window.title = "한쪽 설정"
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
                panel.nameFieldStringValue = "hanjjok-export.md"
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
    #if DEBUG
    // 스토어 스크린샷용 개발 훅. HANJJOK_SNAPSHOT_DIR 환경변수로 실행했을 때만 활성.
    // <dir>/snap.req 에 이름을 쓰면 패널 뷰 계층을 2x 비트맵으로 렌더해 <dir>/<이름>.png 로 저장한다.
    // 화면 기록 권한·디스플레이 배율과 무관하며 배경 없이 패널만(알파) 나온다. 릴리스 빌드에는 포함되지 않는다.
    private var snapshotTimer: Timer?
    private func installSnapshotHookIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["HANJJOK_SNAPSHOT_DIR"] else { return }
        let base = URL(fileURLWithPath: dir)
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            let req = base.appendingPathComponent("snap.req")
            guard let raw = try? String(contentsOf: req, encoding: .utf8), let view = self?.hostView else { return }
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = view.bounds
            guard b.width > 0, b.height > 0,
                  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(b.width * 2), pixelsHigh: Int(b.height * 2),
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
            rep.size = b.size
            view.cacheDisplay(in: b, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: base.appendingPathComponent("\(name).png"))
            try? FileManager.default.removeItem(at: req)
        }
    }
    #endif
}
