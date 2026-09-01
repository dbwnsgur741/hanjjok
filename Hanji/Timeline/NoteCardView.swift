import SwiftUI
import AppKit
import Domain

/// 떡메모지 한 장 — 본문·태그 칩·시각, 더블클릭/우클릭으로 인라인 수정, 우클릭 메뉴로 삭제.
/// `contentText`는 검색 매치 구간을 jjok으로 하이라이트하는 AttributedString을 렌더링한다 (Task 13).
/// [Task 19] 호버 시 우상단에 수정·폴더 이동·삭제 아이콘 3개가 페이드인한다(기존 더블클릭/
/// 우클릭 경로는 그대로 유지 — 중복 진입 허용).
/// [Task 22] `ChecklistParser.items`가 비어 있지 않으면 `contentText` 대신 `checklistBody`를
/// 줄 단위로 렌더링한다 — 이 경로는 검색 매치 하이라이트를 생략한다(Ruling: 카드 자체가
/// 검색 결과로 필터링되므로 손실 최소). 인라인 수정 모드는 항상 원문 마커가 보이는
/// 순수 텍스트(ComposerTextView)로, 체크리스트 여부와 무관하게 그대로 유지한다.
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
            } else if checklistItems.isEmpty {
                contentText
            } else {
                checklistBody
            }

            HStack(spacing: 6) {
                ForEach(HashtagParser.tags(in: note.content), id: \.self) { tag in
                    tagChip(tag)
                }
                Spacer(minLength: 0)
                if checklistProgress.total > 0 {
                    Text("\(checklistProgress.checked)/\(checklistProgress.total)")
                        .font(HanjiTheme.uiFont(size: 10.5))
                        .foregroundStyle(inkSoft)
                        .monospacedDigit()
                    Text("·")
                        .font(HanjiTheme.uiFont(size: 10.5))
                        .foregroundStyle(inkSoft)
                }
                Text(timestampLabel)
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
    /// card 톤 배경(hoverActionsBackground)이 없으면 본문 텍스트 위에 아이콘이 그대로
    /// 얹혀 우측 끝 텍스트와 겹치고 휴지통을 오클릭할 위험이 있다(리뷰 지적) — 그래서
    /// 아이콘 행을 "텍스트 위에 떠 있는 작은 컨트롤"로 읽히게 배경을 준다.
    private var hoverActionsRow: some View {
        HStack(spacing: 6) {
            HoverIconButton(systemName: "pencil", inkSoft: inkSoft, ink: ink, action: beginEditing)
            HoverFolderMenuButton(inkSoft: inkSoft, ink: ink) { moveMenuItems }
            HoverIconButton(systemName: "trash", inkSoft: inkSoft, ink: ink) {
                Task { await model.delete(note) }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(hoverActionsBackground)
        .padding(6)
        .opacity(isHovering && !isEditing ? 1 : 0)
        .allowsHitTesting(isHovering && !isEditing)
    }

    /// 호버 아이콘 배경 — card 톤 RoundedRectangle(카드 반경과 동일한 6) + 카드 그림자보다
    /// 약한 그림자 한 겹(반경·알파를 cardBackground의 1차 그림자보다 낮춤).
    private var hoverActionsBackground: some View {
        RoundedRectangle(cornerRadius: HanjiTheme.cardRadius)
            .fill(card)
            .shadow(
                color: (isDark ? HanjiTheme.cardShadow1Dark : HanjiTheme.cardShadow1Light).opacity(0.6),
                radius: isDark ? 1.2 : 1, y: 0.5)
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

    /// [Task 24] 카드 푸터 시각 — 생성 시각(`HH:mm`, 기존 `.shortened` 유지)에 `updatedAt`이
    /// 있으면 " · 수정 " 을 병기한다. 수정일이 생성일과 같은 날이면 시각만(`14:30`),
    /// 다른 날이면 "9월 1일 14:30"처럼 날짜까지 보여준다(ko_KR DateFormatter,
    /// TimelineView.groupedByDay의 DaySeparator 날짜 표기 관례와 동일한 포맷).
    private var timestampLabel: String {
        let created = note.createdAt.formatted(date: .omitted, time: .shortened)
        guard let updatedAt = note.updatedAt else { return created }
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = Calendar.current.isDate(updatedAt, inSameDayAs: note.createdAt)
            ? "HH:mm"
            : "M월 d일 HH:mm"
        return "\(created) · 수정 \(df.string(from: updatedAt))"
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

    /// note.content에 체크리스트 항목이 하나라도 있으면 `checklistBody` 경로가 활성화된다.
    private var checklistItems: [ChecklistItem] {
        ChecklistParser.items(in: note.content)
    }

    private var checklistProgress: (checked: Int, total: Int) {
        ChecklistParser.progress(in: note.content)
    }

    /// `checklistBody` 렌더링 단위 — 체크리스트 항목 줄과 일반 줄을 순서대로 섞어 보관한다.
    private struct ChecklistLine: Identifiable {
        let id: Int
        let text: Substring
        let item: ChecklistItem?
    }

    /// note.content를 `\n` 기준으로 쪼개 Character 오프셋을 추적하며, `checklistItems`의
    /// lineRange와 정확히 일치하는 줄만 체크리스트 항목으로 표시한다(ChecklistParser와
    /// 동일한 분할 규칙 — split(separator: "\n", omittingEmptySubsequences: false)).
    private var checklistLines: [ChecklistLine] {
        let items = checklistItems
        var result: [ChecklistLine] = []
        var offset = 0
        var itemIndex = 0
        for (index, line) in note.content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let range = offset..<(offset + line.count)
            var matched: ChecklistItem? = nil
            if itemIndex < items.count, items[itemIndex].lineRange == range {
                matched = items[itemIndex]
                itemIndex += 1
            }
            result.append(ChecklistLine(id: index, text: line, item: matched))
            offset += line.count + 1  // "\n" 몫
        }
        return result
    }

    /// 체크리스트 본문 — 항목 줄은 체크박스+본문 HStack, 일반 줄은 기존과 같은 plain Text.
    /// 검색 매치 하이라이트는 이 경로에서 생략한다(Ruling, 클래스 상단 주석 참조).
    private var checklistBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(checklistLines) { line in
                if let item = line.item {
                    checklistRow(item)
                } else {
                    Text(String(line.text))
                        .font(HanjiTheme.bodyFont())
                        .lineSpacing((HanjiTheme.bodyLineHeightMultiple - 1) * 15)
                        .textSelection(.enabled)
                }
            }
        }
    }

    /// 체크리스트 항목 한 줄 — 체크박스(11.5pt, unchecked=inkSoft·checked=jjok) + 본문.
    /// 완료 항목은 취소선 + inkSoft로 흐리게, 미완료 항목은 일반 본문과 같은 색(환경 기본 ink).
    private func checklistRow(_ item: ChecklistItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                Task { await model.update(note, content: ChecklistParser.toggling(note.content, at: item)) }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.square" : "square")
                    .font(.system(size: 11.5))
                    .foregroundStyle(item.isChecked ? jjok : inkSoft)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(HanjiTheme.bodyFont())
                .lineSpacing((HanjiTheme.bodyLineHeightMultiple - 1) * 15)
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? inkSoft : ink)
                .textSelection(.enabled)
        }
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
