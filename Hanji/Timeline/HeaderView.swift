import SwiftUI
import AppKit

/// [v1.1] 앱 크롬 — 사용자 피드백("메모앱 느낌이 안 남") 대응 상단 헤더.
/// 좌: "한지" 워드마크 + 현재 필터명(전체/미분류/폴더명/#태그, TimelineModel.filterName).
/// 우: 검색·서랍·설정 아이콘. 서랍(tray) 액션은 TimelineModel.toggleDrawer()에 연결된다
/// (Task 18) — onTray 기본값은 단위 프리뷰 등에서 값을 안 넘겨도 되게 하는 빈 클로저.
struct HeaderView: View {
    let filterName: String
    var onSearch: () -> Void
    var onTray: () -> Void = {}
    var onSettings: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var inkSoft: Color { scheme == .dark ? HanjiTheme.inkSoftDark : HanjiTheme.inkSoftLight }

    var body: some View {
        HStack(spacing: 8) {
            Text("한지")
                .font(HanjiTheme.bodyBoldFont(size: 15))
            Text(filterName)
                .font(HanjiTheme.uiFont(size: 11))
                .foregroundStyle(inkSoft)
            Spacer(minLength: 0)
            HeaderIconButton(systemName: "magnifyingglass", inkSoft: inkSoft, action: onSearch)
            HeaderIconButton(systemName: "tray", inkSoft: inkSoft, action: onTray)
            HeaderIconButton(systemName: "gearshape", inkSoft: inkSoft, action: onSettings)
        }
        .padding(.horizontal, HanjiTheme.panelHorizontalMargin)
        .padding(.vertical, 10)
    }
}

/// 헤더 아이콘 공통 스타일 — SF Symbol template, inkSoft 기본, 호버 시 ink로 전환.
private struct HeaderIconButton: View {
    let systemName: String
    let inkSoft: Color
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    private var ink: Color { scheme == .dark ? HanjiTheme.inkDark : HanjiTheme.inkLight }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isHovering ? ink : inkSoft)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
