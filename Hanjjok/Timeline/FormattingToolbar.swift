import SwiftUI

/// 서식 툴바 — 굵게·제목·불릿·체크리스트·인용·구분선. 메인 컴포저와 카드 인라인 수정이
/// 같은 뷰를 쓴다. 예전에는 TimelineView 안의 사적 뷰였고 수정 모드에는 툴바가 없어서,
/// 처음부터 체크리스트로 만들지 않은 메모에는 나중에 체크박스를 넣을 방법이 없었다
/// (사용자: "체크 박스로 안 만들면 체크 박스를 넣을 수가 없잖아").
///
/// 각 버튼은 ComposerCommands를 거쳐 NSTextView에 직접 반영되고(undo 등록·textDidChange
/// 발화 보장), 액션이 끝나면 ComposerCommands.restoreFocus가 포커스를 텍스트뷰로 되돌린다
/// (그러지 않으면 버튼 클릭 후 다음 타이핑이 씹힌다). ⌘B는 이 버튼의 전역 단축키가 아니라
/// 포커스된 HanjjokTextView가 직접 처리한다 — 전역이었을 땐 카드 수정 중 ⌘B가 아래
/// 컴포저에 `**`를 넣었다.
struct FormattingToolbar: View {
    let commands: ComposerCommands
    /// 오른쪽 끝 입력 규칙 힌트. 컴포저와 수정 필드의 Enter 규칙이 다르므로 호출부가
    /// 각자 맞는 문구를 넘긴다(nil이면 힌트 없음).
    var hint: String? = nil

    @Environment(\.colorScheme) private var scheme
    private var ink: Color { scheme == .dark ? HanjjokTheme.inkDark : HanjjokTheme.inkLight }
    private var inkSoft: Color { scheme == .dark ? HanjjokTheme.inkSoftDark : HanjjokTheme.inkSoftLight }

    var body: some View {
        HStack(spacing: 2) {
            ComposerIconButton(systemName: "bold", inkSoft: inkSoft, ink: ink, iconSize: 12, frameSize: 20) {
                commands.wrapSelection(with: "**")
            }
            ComposerIconButton(systemName: "textformat.size", inkSoft: inkSoft, ink: ink, iconSize: 12, frameSize: 20) {
                commands.togglePrefix("## ")
            }
            ComposerIconButton(systemName: "list.bullet", inkSoft: inkSoft, ink: ink, iconSize: 12, frameSize: 20) {
                commands.togglePrefix("- ")
            }
            ComposerIconButton(systemName: "checklist", inkSoft: inkSoft, ink: ink, iconSize: 12, frameSize: 20) {
                commands.togglePrefix("- [ ] ")
            }
            ComposerIconButton(systemName: "text.quote", inkSoft: inkSoft, ink: ink, iconSize: 12, frameSize: 20) {
                commands.togglePrefix("> ")
            }
            ComposerIconButton(systemName: "minus", inkSoft: inkSoft, ink: ink, iconSize: 12, frameSize: 20) {
                commands.insertDivider()
            }
            Spacer(minLength: 0)
            if let hint {
                Text(hint)
                    .font(HanjjokTheme.uiFont(size: 10.5))
                    .foregroundStyle(inkSoft)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

/// [Task 24] 컴포저 아이콘 버튼 — HeaderView.HeaderIconButton과 같은 관례
/// (SF Symbol template, inkSoft 기본, 호버 시 ink로 전환). 기본 13pt/22×22 히트 영역.
/// [QA r5-C] 서식 툴바는 패널 폭이 좁아 12pt/20×20으로 쓴다.
struct ComposerIconButton: View {
    let systemName: String
    let inkSoft: Color
    let ink: Color
    var iconSize: CGFloat = 13
    var frameSize: CGFloat = 22
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(isHovering ? ink : inkSoft)
                .frame(width: frameSize, height: frameSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
