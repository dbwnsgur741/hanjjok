import SwiftUI
import AppKit
import Domain

/// 떡메모지 한 장 — 본문·태그 칩·시각, 더블클릭/우클릭으로 인라인 수정, 우클릭 메뉴로 삭제.
/// `contentText`는 검색 매치 구간을 jjok으로 하이라이트하는 AttributedString을 렌더링한다 (Task 13).
/// [Task 19] 호버 시 우상단에 수정·폴더 이동·삭제 아이콘 3개가 페이드인한다(기존 더블클릭/
/// 우클릭 경로는 그대로 유지 — 중복 진입 허용).
/// [QA r5-B] 평상시 렌더는 `MarkdownBody`(제목·구분선·불릿·인용·체크리스트·인라인 서식이
/// 마커 없는 완성형으로 보임)로 통일한다 — 예전엔 체크리스트가 있을 때만 줄 단위 렌더
/// (`checklistBody`, Task 22)로 빠졌고 그 밖의 마크다운(`**굵게**`, `---` 등)은 평문 그대로
/// 보였다(사용자 피드백). 다만 검색 중(`model.currentSearchText != nil`)에는 매치 하이라이트가
/// 있는 `contentText`(평문)를 그대로 쓴다 — MarkdownBody는 하이라이트 구간을 모른다(Ruling,
/// 기존 "체크리스트 경로는 하이라이트 생략" 규칙을 이걸로 대체). 인라인 수정 모드는 항상
/// 원문 마커가 보이는 순수 텍스트(ComposerTextView)로, 마크다운 유무와 무관하게 그대로 유지한다.
struct NoteCardView: View {
    let note: Note
    let model: TimelineModel
    @Environment(\.colorScheme) private var scheme

    // [QA r3 ⑤-b] 예전엔 카드마다 로컬 @State로 수정 중 여부를 들고 있어 카드 여러 개를
    // 동시에 수정 가능한 버그가 있었다. model.editingNoteID를 앱 전체 단일 진실 소스로
    // 삼아, 이 카드의 note.id와 같을 때만 수정 UI를 보여준다 — 다른 카드에서
    // beginEditing()을 부르면 이 값이 그쪽 id로 바뀌면서 이 카드는 자동으로 내려간다.
    private var isEditing: Bool { model.editingNoteID == note.id }
    @State private var editText = ""
    // [QA r3 ②] 인라인 수정 필드의 자동 성장 높이 — beginEditing에서 40으로 리셋하지
    // 않는다: onHeightChange가 첫 레이아웃 직후 새 내용 높이를 보고하며 자연히 수렴하고,
    // 리셋하면 진입 시 40 → 실제 높이로 튀는 프레임 점프가 보인다.
    @State private var editHeight: CGFloat = 40
    @State private var isHovering = false

    private var isDark: Bool { scheme == .dark }
    private var card: Color { isDark ? HanjjokTheme.cardDark : HanjjokTheme.cardLight }
    private var ink: Color { isDark ? HanjjokTheme.inkDark : HanjjokTheme.inkLight }
    private var inkSoft: Color { isDark ? HanjjokTheme.inkSoftDark : HanjjokTheme.inkSoftLight }
    private var jjok: Color { isDark ? HanjjokTheme.jjokDark : HanjjokTheme.jjokLight }
    private var jjokWash: Color { isDark ? HanjjokTheme.jjokWashDark : HanjjokTheme.jjokWashLight }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                ComposerTextView(
                    text: $editText,
                    font: HanjjokTheme.bodyNSFont(),
                    onSubmit: { commitEdit() },
                    // [QA r3 ③] 수정 중 다른 곳을 클릭해 포커스를 잃으면 커밋한다 — 예전엔
                    // 포커스 아웃 커밋 경로 자체가 없어 변경 내용이 저장되지 않았다.
                    onFocusLost: { commitEdit() },
                    // [QA r3 ②] 고정 minHeight/maxHeight 대신 내용만큼 자라는 높이로 교체.
                    onHeightChange: { editHeight = min(max($0, 40), 320) })
                    .frame(height: editHeight)
                    // 수정 중 Esc는 수정만 취소한다 — 패널은 닫히지 않는다 (Task 12 요구사항).
                    // onExitCommand는 cancelOperation: 을 responder 체인에서 이 뷰가 소비하도록 하므로
                    // 상위(패널)로 이벤트가 전파되지 않는다. editingNoteID를 nil로 되돌리면
                    // isEditing이 파생 프로퍼티라 자동으로 false가 된다(QA r3).
                    .onExitCommand { model.editingNoteID = nil }
            } else if model.currentSearchText != nil {
                contentText
            } else {
                MarkdownBody(content: note.content) { item in
                    Task { await model.update(note, content: ChecklistParser.toggling(note.content, at: item)) }
                }
            }

            HStack(spacing: 6) {
                ForEach(HashtagParser.tags(in: note.content), id: \.self) { tag in
                    tagChip(tag)
                }
                Spacer(minLength: 0)
                if checklistProgress.total > 0 {
                    Text("\(checklistProgress.checked)/\(checklistProgress.total)")
                        .font(HanjjokTheme.uiFont(size: 10.5))
                        .foregroundStyle(inkSoft)
                        .monospacedDigit()
                    Text("·")
                        .font(HanjjokTheme.uiFont(size: 10.5))
                        .foregroundStyle(inkSoft)
                }
                Text(timestampLabel)
                    .font(HanjjokTheme.uiFont(size: 10.5))
                    .foregroundStyle(inkSoft)
            }
        }
        .padding(.vertical, HanjjokTheme.cardPaddingV)
        .padding(.horizontal, HanjjokTheme.cardPaddingH)
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
            HanjjokTheme.motion { isHovering = hovering }
        }
    }

    /// 호버 시 우상단에 페이드인하는 아이콘 3개 — 수정 연필·폴더 이동·삭제 휴지통.
    /// 수정 모드 중에는 (기존 인라인 편집 UI와 겹치지 않도록) 숨긴다. 페이드는
    /// HanjjokTheme.motion을 거쳐 ≤200ms로 애니메이션되며, '동작 줄이기' 활성 시 즉시 전환된다.
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
        RoundedRectangle(cornerRadius: HanjjokTheme.cardRadius)
            .fill(card)
            .shadow(
                color: (isDark ? HanjjokTheme.cardShadow1Dark : HanjjokTheme.cardShadow1Light).opacity(0.6),
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
            .font(HanjjokTheme.bodyFont())
            .lineSpacing((HanjjokTheme.bodyLineHeightMultiple - 1) * 15)
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

    /// 카드 푸터 진행률(n/m) — MarkdownBody가 체크리스트 렌더를 맡은 뒤에도 그대로 유지한다.
    private var checklistProgress: (checked: Int, total: Int) {
        ChecklistParser.progress(in: note.content)
    }

    private func tagChip(_ tag: String) -> some View {
        let color = HanjjokTheme.tagColor(tag, dark: isDark)
        return Text("#\(tag)")
            .font(HanjjokTheme.uiFont(size: 12.5, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(HanjjokTheme.tagChipAlpha)))
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
        RoundedRectangle(cornerRadius: HanjjokTheme.cardRadius)
            .fill(card)
            .shadow(
                color: isDark ? HanjjokTheme.cardShadow1Dark : HanjjokTheme.cardShadow1Light,
                radius: isDark ? 2 : 1.5, y: 1)
            .shadow(
                color: isDark ? HanjjokTheme.cardShadow2Dark : HanjjokTheme.cardShadow2Light,
                radius: 0.5, y: 0)
    }

    private func beginEditing() {
        editText = note.content
        model.editingNoteID = note.id
    }

    /// [QA r3 ③] `model.editingNoteID`가 여전히 이 카드를 가리킬 때만 커밋한다. 이 guard가
    /// 없으면 두 경로가 겹칠 때 이중 커밋이 난다 — 예를 들어 Enter로 이미 커밋해
    /// editingNoteID가 nil이 된 뒤 텍스트 필드 teardown이 뒤늦게 textDidEndEditing을 보내는
    /// 경우, 또는 Esc로 editingNoteID를 nil로 되돌린 뒤 같은 teardown이 오는 경우.
    /// 카드 전환 시(새 카드 beginEditing → 이전 카드 포커스 아웃) 이벤트 도착 순서는
    /// 일반적으로 "이전 NSTextView의 textDidEndEditing이 먼저, 새 beginEditing이 그다음"이라
    /// guard 통과 시점엔 아직 editingNoteID가 이전 카드를 가리켜 정상 커밋되지만, 반대
    /// 순서로 도착해도(새 beginEditing이 먼저 editingNoteID를 새 id로 바꿔버린 경우) 이
    /// guard가 이전 카드의 커밋을 조용히 막아 이중 커밋은 막힌다 — 다만 그 경우 이전 카드의
    /// 미커밋 변경은 유실된다(수동 확인 필요, 브리프 §C.2 명시적 언급).
    private func commitEdit() {
        guard model.editingNoteID == note.id else { return }
        // [QA r4 ②] 변경이 없으면 저장 없이 종료 — updatedAt이 헛되이 갱신되어
        // "수정" 표기가 붙는 것을 막는다.
        guard editText != note.content else { model.editingNoteID = nil; return }
        let text = editText
        Task {
            await model.update(note, content: text)
        }
        model.editingNoteID = nil
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
