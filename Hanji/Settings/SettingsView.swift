import SwiftUI
import ServiceManagement
import KeyboardShortcuts
import PanelKit

/// 설정 창. `panelSide`/`panelWidth`/`usePretendardBody`는 UserDefaults(@AppStorage)에
/// 직접 기록되고, AppDelegate가 UserDefaults.didChangeNotification을 구독해 패널에
/// 즉시 반영한다 (HanjiApp.swift 참고). 본문 글꼴은 TimelineView의 @AppStorage 관찰로
/// 이미 열려 있는 패널에도 바로 반영된다.
struct SettingsView: View {
    @AppStorage("panelSide") private var panelSide = PanelSide.right.rawValue
    @AppStorage("panelWidth") private var panelWidth = 360.0
    @AppStorage("usePretendardBody") private var usePretendardBody = false
    // [Task 24] "system"(기본)/"light"/"dark" — AppDelegate.applyAppearance()가
    // UserDefaults.didChangeNotification을 거쳐 NSApp.appearance에 즉시 반영한다.
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("패널 단축키:", name: .togglePanel)
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
        }
        .padding(20)
        .frame(width: 340)
    }
}
