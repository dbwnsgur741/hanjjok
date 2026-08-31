import SwiftUI
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
    }
}
