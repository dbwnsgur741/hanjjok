import SwiftUI
import AppKit
import Domain

/// 떡메모지 한 장 — 본문·태그 칩·시각, 더블클릭/우클릭으로 인라인 수정, 우클릭 메뉴로 삭제.
/// Task 13은 `contentText`(본문 렌더링을 한곳에 모아둔 계산 프로퍼티)를 AttributedString 기반
/// 검색 하이라이트로 교체할 예정이다 — 본문 렌더링 로직을 변경할 때는 이 프로퍼티만 건드리면 된다.
struct NoteCardView: View {
    let note: Note
    let model: TimelineModel
    @Environment(\.colorScheme) private var scheme

    @State private var isEditing = false
    @State private var editText = ""

    private var isDark: Bool { scheme == .dark }
    private var card: Color { isDark ? HanjiTheme.cardDark : HanjiTheme.cardLight }
    private var inkSoft: Color { isDark ? HanjiTheme.inkSoftDark : HanjiTheme.inkSoftLight }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                ComposerTextView(
                    text: $editText,
                    font: HanjiTheme.bodyNSFont(),
                    onSubmit: { commitEdit() })
                    .frame(minHeight: 40, maxHeight: 200)
                    // 수정 중 Esc는 수정만 취소한다 — 패널은 닫히지 않는다 (Task 12 요구사항).
                    // onExitCommand는 cancelOperation: 을 responder 체인에서 이 뷰가 소비하도록 하므로
                    // 상위(패널)로 이벤트가 전파되지 않는다.
                    .onExitCommand { isEditing = false }
            } else {
                contentText
            }

            HStack(spacing: 6) {
                ForEach(HashtagParser.tags(in: note.content), id: \.self) { tag in
                    tagChip(tag)
                }
                Spacer(minLength: 0)
                Text(note.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(HanjiTheme.uiFont(size: 10.5))
                    .foregroundStyle(inkSoft)
            }
        }
        .padding(.vertical, HanjiTheme.cardPaddingV)
        .padding(.horizontal, HanjiTheme.cardPaddingH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .contextMenu {
            Button("수정") { beginEditing() }
            Button("삭제", role: .destructive) {
                Task { await model.delete(note) }
            }
        }
        .onTapGesture(count: 2) { beginEditing() }
    }

    /// 본문 렌더링 — Task 13에서 검색 매치 하이라이트를 위해 AttributedString으로 교체될 지점.
    private var contentText: some View {
        Text(note.content)
            .font(HanjiTheme.bodyFont())
            .lineSpacing((HanjiTheme.bodyLineHeightMultiple - 1) * 15)
            .textSelection(.enabled)
    }

    private func tagChip(_ tag: String) -> some View {
        let color = HanjiTheme.tagColor(tag, dark: isDark)
        return Text("#\(tag)")
            .font(HanjiTheme.uiFont(size: 12.5, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(HanjiTheme.tagChipAlpha)))
            .foregroundStyle(color)
    }

    /// tokens.md 카드 그림자 — 이중 레이어(주 그림자 + 밀착 윤곽 그림자)를 라이트/다크로 분기.
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: HanjiTheme.cardRadius)
            .fill(card)
            .shadow(
                color: isDark ? HanjiTheme.cardShadow1Dark : HanjiTheme.cardShadow1Light,
                radius: isDark ? 2 : 1.5, y: 1)
            .shadow(
                color: isDark ? HanjiTheme.cardShadow2Dark : HanjiTheme.cardShadow2Light,
                radius: 0.5, y: 0)
    }

    private func beginEditing() {
        editText = note.content
        isEditing = true
    }

    private func commitEdit() {
        let text = editText
        Task {
            await model.update(note, content: text)
        }
        isEditing = false
    }
}
