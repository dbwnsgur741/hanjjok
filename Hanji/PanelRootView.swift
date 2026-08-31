import SwiftUI
import AppKit
import Domain
import Data

struct PanelRootView: View {
    let model: TimelineModel

    var body: some View {
        TimelineView(model: model)
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
            // Esc — 1차: 검색/태그 필터 중이면 종료. 2차: 패널을 닫는다.
            // (카드 인라인 수정 중 Esc는 NoteCardView.onExitCommand가 더 안쪽에서 먼저 소비한다.)
            .onExitCommand {
                if model.isSearching || model.activeTag != nil {
                    model.exitSearch()
                } else {
                    (NSApp.delegate as? AppDelegate)?.panelController.hide()
                }
            }
    }
}
