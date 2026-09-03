import SwiftUI
import ServiceManagement
import KeyboardShortcuts
import PanelKit

/// 설정 창. `panelSide`/`panelWidth`/`usePretendardBody`는 UserDefaults(@AppStorage)에
/// 직접 기록되고, AppDelegate가 UserDefaults.didChangeNotification을 구독해 패널에
/// 즉시 반영한다 (HanjjokApp.swift 참고). 본문 글꼴은 TimelineView의 @AppStorage 관찰로
/// 이미 열려 있는 패널에도 바로 반영된다.
/// [v1.5] 아래 "단축키" 표는 안내 전용 — "수정할 때 Enter인지 뭔지 모르겠다"는 피드백에 대한
/// 한눈 참조. 바꿀 수 있는 건 위 Recorder의 패널 단축키뿐이라, 표의 첫 행은 Recorder 값을
/// 따라간다(onChange로 동기화).
/// [v1.5 fix] **기본값 ⌥Space는 Recorder로 다시 녹화할 수 없다.** KeyboardShortcuts의
/// `Shortcut.isDisallowed`가 macOS 15.0·15.1 + 샌드박스에서 ⌥(·⇧)만 조합한 단축키를 거부하고
/// "Option 수정자는 Command 또는 Control과 함께 사용해야 합니다" 알럿을 띄운다(라이브러리가
/// 참조한 Apple 포럼 763878 이슈의 과잉 방어 — 실제 등록·동작은 정상, 사용자 실사용으로 확인).
/// 사용자가 ⓧ/Delete로 지우고 나면(UserDefaults에 0 저장) 되돌릴 길이 없었던 실사용 버그 —
/// `KeyboardShortcuts.reset`은 Recorder를 거치지 않고 기본값을 쓰므로 그 버튼을 둔다.
struct SettingsView: View {
    @AppStorage("panelSide") private var panelSide = PanelSide.right.rawValue
    @AppStorage("panelWidth") private var panelWidth = 360.0
    @AppStorage("usePretendardBody") private var usePretendardBody = false
    // [Task 24] "system"(기본)/"light"/"dark" — AppDelegate.applyAppearance()가
    // UserDefaults.didChangeNotification을 거쳐 NSApp.appearance에 즉시 반영한다.
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var panelShortcut = Self.panelShortcutLabel()
    @State private var isDefaultShortcut = Self.isPanelShortcutDefault()

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("패널 단축키:", name: .togglePanel) { _ in
                refreshPanelShortcut()
            }
            LabeledContent("") {
                VStack(alignment: .leading, spacing: 4) {
                    Button("기본값 ⌥Space로 되돌리기") {
                        KeyboardShortcuts.reset(.togglePanel)
                        refreshPanelShortcut()
                    }
                    .disabled(isDefaultShortcut)
                    Text("⌥만 조합한 단축키(⌥Space 등)는 이 macOS에서 직접 녹화할 수 없어요. ⌘·⌃가 들어간 조합은 녹화됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Picker("패널 위치:", selection: $panelSide) {
                Text("오른쪽").tag(PanelSide.right.rawValue)
                Text("왼쪽").tag(PanelSide.left.rawValue)
            }
            Picker("본문 글꼴:", selection: $usePretendardBody) {
                Text("마루 부리 (붓글씨)").tag(false)
                Text("프리텐다드 (고딕)").tag(true)
            }
            Picker("화면 모드:", selection: $appearanceMode) {
                Text("시스템").tag("system")
                Text("밝게").tag("light")
                Text("어둡게").tag("dark")
            }
            LabeledContent("패널 폭: \(Int(panelWidth))pt") {
                Slider(value: $panelWidth, in: 300...480, step: 10)
            }
            Toggle("로그인 시 자동 시작", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Section("단축키") {
                shortcutRow("패널 열기 · 닫기", panelShortcut)
                shortcutRow("닫기 · 뒤로", "Esc")
                shortcutRow("검색", "⌘F")
                shortcutRow("삭제 복구", "⌘Z")
                shortcutRow("새 메모 보내기", "Enter")
                shortcutRow("메모 수정 저장", "⌘Enter")
                shortcutRow("줄바꿈", "⇧Enter")
                shortcutRow("굵게", "⌘B")
                shortcutRow("메모 수정 시작", "더블클릭 · 연필 · 우클릭")
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func shortcutRow(_ label: String, _ keys: String) -> some View {
        LabeledContent(label) {
            Text(keys).foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }

    private func refreshPanelShortcut() {
        panelShortcut = Self.panelShortcutLabel()
        isDefaultShortcut = Self.isPanelShortcutDefault()
    }

    private static func isPanelShortcutDefault() -> Bool {
        KeyboardShortcuts.getShortcut(for: .togglePanel) == KeyboardShortcuts.Name.togglePanel.defaultShortcut
    }

    /// Recorder가 저장한 현재 패널 단축키 표기(예: "⌥Space"). 비어 있으면 "미설정".
    private static func panelShortcutLabel() -> String {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .togglePanel) else { return "미설정" }
        return shortcut.description.replacingOccurrences(of: "␣", with: "Space")
    }
}
