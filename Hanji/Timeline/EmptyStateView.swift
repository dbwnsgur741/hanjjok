import SwiftUI

/// [v1.1] 빈 상태 — 첫 실행(또는 전부 지운 뒤) 타임라인 자리에 중앙 표시하는 안내.
/// tokens.md 타이포: 본문 MaruBuri / 힌트 Pretendard inkSoft.
struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    private var inkSoft: Color { scheme == .dark ? HanjiTheme.inkSoftDark : HanjiTheme.inkSoftLight }

    var body: some View {
        VStack(spacing: 6) {
            Text("무엇이든 적어보세요")
                .font(HanjiTheme.bodyFont(size: 15))
            Text("#태그로 분류됩니다 · ⌘F 검색")
                .font(HanjiTheme.uiFont(size: 11))
                .foregroundStyle(inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
