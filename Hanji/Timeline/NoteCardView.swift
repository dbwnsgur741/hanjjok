import SwiftUI
import AppKit
import Domain

/// 떡메모지 한 장 — 본문·태그 칩·시각, 더블클릭/우클릭으로 인라인 수정, 우클릭 메뉴로 삭제.
/// `contentText`는 검색 매치 구간을 jjok으로 하이라이트하는 AttributedString을 렌더링한다 (Task 13).
/// [Task 19] 호버 시 우상단에 수정·폴더 이동·삭제 아이콘 3개가 페이드인한다(기존 더블클릭/
/// 우클릭 경로는 그대로 유지 — 중복 진입 허용).
struct NoteCardView: View {
    let note: Note
    let model: TimelineModel
    @Environment(\.colorScheme) private var scheme

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovering = false

    private var isDark: Bool { scheme == .dark }
    private var card: Color { isDark ? HanjiTheme.cardDark : HanjiTheme.cardLight }
    private var ink: Color { isDark ? HanjiTheme.inkDark : HanjiTheme.inkLight }
    private var inkSoft: Color { isDark ? HanjiTheme.inkSoftDark : HanjiTheme.inkSoftLight }
    private var jjok: Color { isDark ? HanjiTheme.jjokDark : HanjiTheme.jjokLight }
    private var jjokWash: Color { isDark ? HanjiTheme.jjokWashDark : HanjiTheme.jjokWashLight }

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
        .overlay(alignment: .topTrailing) { hoverActionsRow }
        .contextMenu {
            Button("수정") { beginEditing() }
            Menu("폴더로 이동") { moveMenuItems }
            Button("삭제", role: .destructive) {
                Task { await model.delete(note) }
            }
        }
        .onTapGesture(count: 2) { beginEditing() }
        .onHover { hovering in
            HanjiTheme.motion { isHovering = hovering }
        }
    }

    /// 호버 시 우상단에 페이드인하는 아이콘 3개 — 수정 연필·폴더 이동·삭제 휴지통.
    /// 수정 모드 중에는 (기존 인라인 편집 UI와 겹치지 않도록) 숨긴다. 페이드는
    /// HanjiTheme.motion을 거쳐 ≤200ms로 애니메이션되며, '동작 줄이기' 활성 시 즉시 전환된다.
    private var hoverActionsRow: some View {
        HStack(spacing: 4) {
            HoverIconButton(systemName: "pencil", inkSoft: inkSoft, ink: ink, action: beginEditing)
            HoverFolderMenuButton(inkSoft: inkSoft, ink: ink) { moveMenuItems }
            HoverIconButton(systemName: "trash", inkSoft: inkSoft, ink: ink) {
                Task { await model.delete(note) }
            }
        }
        .padding(6)
        .opacity(isHovering && !isEditing ? 1 : 0)
        .allowsHitTesting(isHovering && !isEditing)
    }

    /// 호버 아이콘의 폴더 메뉴와 우클릭 메뉴의 "폴더로 이동" 서브메뉴가 공유하는 항목 —
    /// 미분류 + model.folders, 현재 소속에 체크 표시.
    @ViewBuilder
    private var moveMenuItems: some View {
        folderMenuButton(name: "미분류", isSelected: note.folderId == nil) { move(to: nil) }
        ForEach(model.folders) { folder in
            folderMenuButton(name: folder.name, isSelected: note.folderId == folder.id) {
                move(to: folder.id)
            }
        }
    }

    private func folderMenuButton(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isSelected {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
        }
    }

    private func move(to folderId: UUID?) {
        Task { await model.move(note: note, to: folderId) }
    }

    /// 본문 렌더링 — 검색 매치 구간을 jjok 바탕·전경으로 하이라이트한다 (tokens.md "매치 · 본문").
    private var contentText: some View {
        Text(highlighted(note.content))
            .font(HanjiTheme.bodyFont())
            .lineSpacing((HanjiTheme.bodyLineHeightMultiple - 1) * 15)
            .textSelection(.enabled)
    }

    /// SearchHighlighter가 반환하는 Character 오프셋(Range<Int>)을 AttributedString 인덱스로
    /// 변환해 매치 구간만 배경·전경을 jjok으로 물들인다.
    private func highlighted(_ content: String) -> AttributedString {
        var attr = AttributedString(content)
        guard let text = model.currentSearchText,
              let range = SearchHighlighter.range(in: content, matching: text) else { return attr }
        let lower = attr.index(attr.startIndex, offsetByCharacters: range.lowerBound)
        let upper = attr.index(attr.startIndex, offsetByCharacters: range.upperBound)
        attr[lower..<upper].backgroundColor = jjokWash
        attr[lower..<upper].foregroundColor = jjok
        return attr
    }

    private func tagChip(_ tag: String) -> some View {
        let color = HanjiTheme.tagColor(tag, dark: isDark)
        return Text("#\(tag)")
            .font(HanjiTheme.uiFont(size: 12.5, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(HanjiTheme.tagChipAlpha)))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(jjok, lineWidth: tagMatchesQuery(tag) ? 1 : 0)
            )
            .foregroundStyle(color)
            .onTapGesture {
                model.isSearching = true
                model.setTagFilter(tag)
            }
    }

    /// 태그 칩 강조 — tokens.md "매치 · 태그 jjok 1px 테두리": 현재 태그 필터와 일치하거나
    /// 검색어가 태그 문자열 자체와 매치할 때 테두리를 켠다.
    private func tagMatchesQuery(_ tag: String) -> Bool {
        if model.activeTag == tag { return true }
        guard let text = model.currentSearchText else { return false }
        return SearchHighlighter.range(in: tag, matching: text) != nil
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

/// 호버 액션 아이콘 공통 스타일 — HeaderView.HeaderIconButton과 같은 관례(inkSoft 기본,
/// 그 아이콘 위에 직접 커서가 올라가면 ink로 전환).
private struct HoverIconButton: View {
    let systemName: String
    let inkSoft: Color
    let ink: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(isHovering ? ink : inkSoft)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// 호버 아이콘 자리의 "폴더로 이동" — HoverIconButton과 같은 색 관례를 따르는 Menu.
private struct HoverFolderMenuButton<Items: View>: View {
    let inkSoft: Color
    let ink: Color
    @ViewBuilder let items: () -> Items

    @State private var isHovering = false

    var body: some View {
        Menu {
            items()
        } label: {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(isHovering ? ink : inkSoft)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovering = $0 }
    }
}
