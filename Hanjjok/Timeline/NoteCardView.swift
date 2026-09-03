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
/// [v1.5] ① 긴 메모 접기 — 본문 자연 높이가 HanjjokTheme.collapseThreshold를 넘으면
/// collapsedBodyHeight에서 잘라 페이드 + "더 보기"를 보인다(수정 모드·검색 중엔 안 접는다 —
/// 검색은 매치 구간이 가려지면 안 된다). ② 수정 규칙을 화면에 드러낸다 — Enter 줄바꿈 ·
/// ⌘Enter 저장 · Esc 취소(사용자 결정: 에디터식) 힌트와 [취소]/[저장] 푸터 버튼.
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
    // [v1.5] 수정 필드 전용 브릿지 — [저장] 버튼·⌘Enter는 텍스트뷰 포커스를 뺏지 않으므로 한글
    // 조합 중 글자를 finalizeAndReadText로 먼저 확정해야 한다(컴포저 보내기 버튼과 같은 이유,
    // QA r3 ⑤-a).
    @State private var editCommands = ComposerCommands()
    // [v1.5] 커서가 [취소]/[저장] 버튼 위에 있는 동안은 포커스 아웃 자동 저장을 멈춘다 — 버튼
    // 클릭으로 텍스트뷰가 포커스를 잃으면 textDidEndEditing(자동 저장)이 버튼 액션보다 먼저
    // 도착해 "취소를 눌렀는데 저장됨"이 된다. 버튼을 누르려면 커서가 먼저 그 위에 와야 하므로
    // onHover가 항상 클릭보다 앞선다. 최종 처리는 버튼 액션(commitEdit/cancelEdit)이 맡는다.
    @State private var pointerOverEditButtons = false
    // [v1.5] 본문 자연 높이(접기 판정용). LazyVStack이 카드를 재생성하면 0으로 돌아가지만
    // 첫 레이아웃에서 바로 다시 측정되고, 그 사이엔 roughlyLong 휴리스틱이 자리를 지킨다.
    @State private var bodyNaturalHeight: CGFloat = 0

    private var isDark: Bool { scheme == .dark }
    private var card: Color { isDark ? HanjjokTheme.cardDark : HanjjokTheme.cardLight }
    private var ink: Color { isDark ? HanjjokTheme.inkDark : HanjjokTheme.inkLight }
    private var inkSoft: Color { isDark ? HanjjokTheme.inkSoftDark : HanjjokTheme.inkSoftLight }
    private var jjok: Color { isDark ? HanjjokTheme.jjokDark : HanjjokTheme.jjokLight }
    private var jjokWash: Color { isDark ? HanjjokTheme.jjokWashDark : HanjjokTheme.jjokWashLight }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                editor
            } else if model.currentSearchText != nil {
                contentText
            } else {
                collapsibleBody
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
            // [v1.5] 본문 textSelection을 없애면서 생긴 "그냥 복사하고 싶다"의 통로 — 카드 전체
            // 원문을 클립보드로. 부분 복사는 수정 모드에서 선택해 ⌘C.
            Button("복사") { copyToPasteboard() }
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

    // MARK: - 인라인 수정 (v1.5: Enter 줄바꿈 · ⌘Enter 저장 · Esc 취소 · 푸터 버튼)

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            ComposerTextView(
                text: $editText,
                font: HanjjokTheme.bodyNSFont(),
                onSubmit: { commitEdit() },
                // [v1.5] 수정 모드는 Enter가 줄바꿈이다(에디터식, 사용자 결정) — 저장은 ⌘Enter·
                // [저장] 버튼·포커스 아웃. 컴포저(Enter 보내기)와 다르므로 푸터 힌트로 드러낸다.
                enterSubmits: false,
                // [v1.5] 진입 즉시 캐럿이 필드 끝에 있어야 한다 — 예전엔 더블클릭 뒤 한 번 더
                // 클릭해야 타이핑이 들어갔다(실측). 컴포저는 패널 표시 시점에 따로 포커스한다.
                autoFocus: true,
                commands: editCommands,
                // [QA r3 ③] 수정 중 다른 곳을 클릭해 포커스를 잃으면 커밋한다 — 예전엔
                // 포커스 아웃 커밋 경로 자체가 없어 변경 내용이 저장되지 않았다.
                // [v1.5] 단, 커서가 푸터 버튼 위면 그 버튼 액션에 맡긴다(pointerOverEditButtons 주석).
                onFocusLost: { if !pointerOverEditButtons { commitEdit() } },
                // [QA r3 ②] 고정 minHeight/maxHeight 대신 내용만큼 자라는 높이로 교체.
                onHeightChange: { editHeight = min(max($0, 40), 320) })
                .frame(height: editHeight)
                // 수정 중 Esc는 수정만 취소한다 — 패널은 닫히지 않는다 (Task 12 요구사항).
                // onExitCommand는 cancelOperation: 을 responder 체인에서 이 뷰가 소비하도록 하므로
                // 상위(패널)로 이벤트가 전파되지 않는다. editingNoteID를 nil로 되돌리면
                // isEditing이 파생 프로퍼티라 자동으로 false가 된다(QA r3).
                .onExitCommand { cancelEdit() }
            editFooter
        }
    }

    /// [v1.5] 수정 푸터 — 왼쪽 규칙 힌트, 오른쪽 [취소]/[저장]. 힌트에 Enter를 굳이 적지 않는다
    /// (줄바꿈은 텍스트 필드의 기본 기대와 같고, 다른 것만 알려주면 된다).
    private var editFooter: some View {
        HStack(spacing: 8) {
            Text("⌘Enter 저장 · Esc 취소")
                .font(HanjjokTheme.uiFont(size: 10.5))
                .foregroundStyle(inkSoft)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                EditFooterButton(title: "취소", style: .quiet, inkSoft: inkSoft, ink: ink,
                                 jjok: jjok, jjokWash: jjokWash, action: cancelEdit)
                EditFooterButton(title: "저장", style: .primary, inkSoft: inkSoft, ink: ink,
                                 jjok: jjok, jjokWash: jjokWash, action: commitEdit)
            }
            .onHover { pointerOverEditButtons = $0 }
        }
    }

    // MARK: - 긴 메모 접기 (v1.5)

    /// 접기 대상인가 — 측정값(bodyNaturalHeight)이 있으면 그것으로, 아직 0이면(첫 프레임) 원문
    /// 길이 휴리스틱으로 미리 접어 "펼쳐졌다 → 접힘" 한 프레임 점프를 줄인다.
    private var isLongBody: Bool {
        if bodyNaturalHeight > 0 { return bodyNaturalHeight > HanjjokTheme.collapseThreshold }
        return Self.roughlyLong(note.content)
    }
    private var isCollapsed: Bool { isLongBody && !model.expandedNoteIDs.contains(note.id) }
    private var isExpanded: Bool { model.expandedNoteIDs.contains(note.id) }

    /// 대략 11줄(collapseThreshold) 이상으로 보이는가 — 본문 15pt에서 패널 폭 기준 한 줄 ≈ 20~25자.
    static func roughlyLong(_ content: String) -> Bool {
        content.count > 320 || content.filter { $0 == "\n" }.count >= 11
    }

    private var collapsibleBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarkdownBody(content: note.content) { item in
                Task { await model.update(note, content: ChecklistParser.toggling(note.content, at: item)) }
            }
            // 높이 제안과 무관하게 자연 높이로 배치해 배경 GeometryReader가 전체 높이를 재고,
            // 바깥 frame(maxHeight:) + clipped가 접힌 만큼만 보여준다. 접히지 않은 카드에서는
            // maxHeight가 nil이라 예전과 같은 레이아웃이다.
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: BodyHeightKey.self, value: proxy.size.height)
            })
            .frame(maxHeight: isCollapsed ? HanjjokTheme.collapsedBodyHeight : nil, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                if isCollapsed {
                    // 잘린 자리를 card 톤으로 흐려 "아래에 더 있다"를 읽히게 한다(순검정 금지 원칙).
                    LinearGradient(colors: [card.opacity(0), card], startPoint: .top, endPoint: .bottom)
                        .frame(height: 44)
                        .allowsHitTesting(false)
                }
            }
            if isLongBody {
                ExpandToggle(
                    title: isExpanded ? "접기" : "더 보기",
                    systemName: isExpanded ? "chevron.up" : "chevron.down",
                    inkSoft: inkSoft, ink: ink) { model.toggleExpanded(note.id) }
                    // 더블클릭은 카드 수정 진입이므로 이 행에서 삼킨다 — 펼침 버튼을 연타해 수정
                    // 모드로 들어가는 사고 방지(자식 제스처가 부모보다 우선).
                    .onTapGesture(count: 2) {}
            }
        }
        .onPreferenceChange(BodyHeightKey.self) { bodyNaturalHeight = $0 }
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

    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(note.content, forType: .string)
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
            // [v1.5] textSelection 없음 — MarkdownBody와 같은 이유(더블클릭 수정 진입 보장).
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
        // [v1.5] 이미 수정 중이면 무시 — 수정 필드 안에서 단어를 더블클릭해 선택할 때 카드의
        // 더블클릭 제스처가 함께 발화하면 editText가 원문으로 되돌아가 작성 중 내용을 잃는다.
        guard !isEditing else { return }
        editText = note.content
        model.editingNoteID = note.id
    }

    /// [v1.5] Esc·[취소] 공통 — 변경을 버리고 수정 모드를 닫는다. editingNoteID가 nil이 되면
    /// 텍스트뷰가 내려가며 textDidEndEditing이 뒤늦게 와도 commitEdit의 id 가드가 막는다.
    private func cancelEdit() {
        model.editingNoteID = nil
    }

    /// [QA r3 ③] `model.editingNoteID`가 여전히 이 카드를 가리킬 때만 커밋한다. 이 guard가
    /// 없으면 두 경로가 겹칠 때 이중 커밋이 난다 — 예를 들어 ⌘Enter로 이미 커밋해
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
        // [v1.5] [저장] 버튼·⌘Enter 경로는 텍스트뷰 포커스가 그대로라 한글 조합 중(marked)
        // 글자가 남아 있을 수 있다 — 먼저 확정해서 읽는다(컴포저 보내기 버튼과 같은 처리).
        if let text = editCommands.finalizeAndReadText() { editText = text }
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

/// [v1.5] 본문 자연 높이 전달용 — 접기 판정(NoteCardView.isLongBody)에 쓴다.
private struct BodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// [v1.5] "더 보기 ▾ / 접기 ▴" 행 — 카드 푸터 라벨과 같은 Pretendard 11pt, inkSoft 기본·호버 ink.
private struct ExpandToggle: View {
    let title: String
    let systemName: String
    let inkSoft: Color
    let ink: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(HanjjokTheme.uiFont(size: 11, weight: .semibold))
            }
            .foregroundStyle(isHovering ? ink : inkSoft)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
    }
}

/// [v1.5] 수정 푸터 버튼 — quiet(취소): inkSoft 글자, 호버 시 ink + 옅은 틴트.
/// primary(저장): jjok 글자 + jjokWash 배경(선택 칩과 같은 관례), 호버 시 배경만 조금 진하게.
private struct EditFooterButton: View {
    enum Style { case quiet, primary }

    let title: String
    let style: Style
    let inkSoft: Color
    let ink: Color
    let jjok: Color
    let jjokWash: Color
    let action: () -> Void

    @State private var isHovering = false

    private var foreground: Color {
        switch style {
        case .quiet: return isHovering ? ink : inkSoft
        case .primary: return jjok
        }
    }
    private var background: Color {
        switch style {
        case .quiet: return isHovering ? inkSoft.opacity(0.08) : .clear
        case .primary: return isHovering ? jjok.opacity(0.26) : jjokWash
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HanjjokTheme.uiFont(size: 11, weight: .semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 3).fill(background))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
