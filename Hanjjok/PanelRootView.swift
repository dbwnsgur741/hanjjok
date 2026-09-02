import SwiftUI
import AppKit
import Domain
import Data

struct PanelRootView: View {
    let model: TimelineModel
    // [Task 24] 헤더 설정 버튼 배선 — AppDelegate가 생성 시 { [weak self] in self?.openSettings() }를
    // 주입한다. TimelineView가 `(NSApp.delegate as? AppDelegate)?.openSettings()`처럼 직접
    // 캐스팅하면 SwiftUI 수명주기의 NSApp.delegate가 내부 델리게이트라 항상 실패했다(실사용 버그).
    let onOpenSettings: () -> Void
    // Esc 최종 단계(패널 닫기)도 같은 이유로 주입받는다 — `NSApp.delegate as? AppDelegate`는
    // SwiftUI 수명주기에서 `SwiftUI.AppDelegate`(동명이지만 다른 타입)를 반환해 항상 nil이 되고,
    // `?.`가 단락되어 hide()가 조용히 호출되지 않았다(실사용 버그: Esc 무반응 + 포커스 미복귀).
    let onRequestHide: () -> Void

    var body: some View {
        TimelineView(model: model, onOpenSettings: onOpenSettings)
            // [v1.1] 플로팅 패널 — "벽에 붙은 판"이 아니라 "떠 있는 종이": 네 모서리를
            // 라운드로 클립하고 바깥에 그림자를 드리운다. SlidePanel 배경은 이미 clear이므로
            // 클립 밖(모서리 바깥) 영역은 그대로 투명하게 비친다.
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.28), radius: 24, y: 8)
            // 삭제 복구 — 카드 안 인라인 수정에 포커스가 없을 때만 여기까지 전파된다.
            .onKeyPress(KeyEquivalent("z"), phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                Task { await model.undoDelete() }
                return .handled
            }
            // ⌘F — 검색 모드 진입. TextField 포커스는 TimelineView가 model.isSearching 변화를
            // 감지해 @FocusState로 맞춘다 (검색 바가 조건부로 삽입되는 시점 이후에 포커스를 줘야 하므로).
            .onKeyPress(KeyEquivalent("f"), phases: .down) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                model.isSearching = true
                return .handled
            }
            // Esc 라우팅 우선순위(Task 18): 드로어 열림 > 수정 중 > 검색 중 > 패널 닫기.
            // "수정 중"은 이 핸들러가 아니라 NoteCardView.onExitCommand(카드 인라인 수정)나
            // DrawerView의 인라인 이름 입력 필드의 onExitCommand가 responder 체인에서 더
            // 안쪽(깊은 뷰)에 있어 먼저 이벤트를 소비하므로, 여기서는 그 다음 두 우선순위만
            // 판단하면 된다.
            .onExitCommand {
                if model.isDrawerOpen {
                    model.closeDrawer()
                } else if model.isSearching || model.activeTag != nil {
                    model.exitSearch()
                } else {
                    onRequestHide()
                }
            }
    }
}
