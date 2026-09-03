import SwiftUI

/// [v1.1] 빈 상태 — 첫 실행(또는 전부 지운 뒤) 타임라인 자리에 중앙 표시하는 안내.
/// tokens.md 타이포: 본문 MaruBuri / 힌트 Pretendard inkSoft.
/// [v1.5] 입력 규칙 한 줄을 더한다 — 첫 화면에서 한 번은 읽고 시작하게(컴포저 툴바 힌트·
/// 설정 "단축키" 표와 같은 문구 체계).
struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    private var inkSoft: Color { scheme == .dark ? HanjjokTheme.inkSoftDark : HanjjokTheme.inkSoftLight }

    var body: some View {
        VStack(spacing: 6) {
            Text("무엇이든 적어보세요")
                .font(HanjjokTheme.bodyFont(size: 15))
            Text("#태그로 분류됩니다 · ⌘F 검색")
                .font(HanjjokTheme.uiFont(size: 11))
                .foregroundStyle(inkSoft)
            Text("Enter 보내기 · ⇧Enter 줄바꿈 · 카드 더블클릭으로 수정")
                .font(HanjjokTheme.uiFont(size: 11))
                .foregroundStyle(inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
