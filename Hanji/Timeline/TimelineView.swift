import SwiftUI
import AppKit
import Domain
import os

private let timelineLog = Logger(subsystem: "kr.hurdlers.Hanji", category: "timeline")

struct TimelineView: View {
    @Bindable var model: TimelineModel
    // [Task 24] PanelRootView가 AppDelegate로부터 받은 클로저를 그대로 전달한다 — 이전에는
    // 여기서 `(NSApp.delegate as? AppDelegate)?.openSettings()`로 직접 캐스팅했는데,
    // SwiftUI 수명주기에서 NSApp.delegate는 내부 델리게이트라 캐스트가 항상 nil이 되어
    // 설정 버튼이 무반응이었다(실사용 버그).
    let onOpenSettings: () -> Void
    @Environment(\.colorScheme) private var scheme
    @FocusState private var searchFieldFocused: Bool
    // [Task 24] 컴포저 체크리스트 버튼이 NSTextView에 직접 마커를 삽입할 때 쓰는 브릿지.
    // 메인 컴포저에만 연결한다(카드 인라인 수정·드로어 이름 필드는 미연결).
    @State private var composerCommands = ComposerCommands()
    // 설정 창에서 본문 글꼴 토글 시 이 패널(생성 후 재사용되는 단일 인스턴스)이 즉시 새로
    // 반영하도록 하는 배선 — @AppStorage는 body 안에서 값을 직접 읽지 않아도 해당
    // UserDefaults 키가 바뀔 때마다 SwiftUI가 이 뷰의 body를 다시 계산하게 만든다.
    // 그러면 하위 NoteCardView.contentText/ComposerTextView가 HanjiTheme.bodyFont(NSFont)를
    // 다시 호출해 새 폰트를 얻는다.
    @AppStorage("usePretendardBody") private var usePretendardBody = false

    private var paper: Color { scheme == .dark ? HanjiTheme.paperDark : HanjiTheme.paperLight }
    private var ink: Color { scheme == .dark ? HanjiTheme.inkDark : HanjiTheme.inkLight }
    // [Task 24] 컴포저 필드 구분 배경/체크리스트 버튼 색.
    private var card: Color { scheme == .dark ? HanjiTheme.cardDark : HanjiTheme.cardLight }
    private var inkSoft: Color { scheme == .dark ? HanjiTheme.inkSoftDark : HanjiTheme.inkSoftLight }
    private var grainTint: Color { scheme == .dark ? HanjiTheme.grainTintDark : HanjiTheme.grainTintLight }
    private var grainOpacity: Double { scheme == .dark ? HanjiTheme.grainOpacityDark : HanjiTheme.grainOpacityLight }

    /// 256pt 타일(원본 512px @2x)로 쓰기 위해 번들 이미지를 복사해 size를 재설정한다.
    /// NSImage(named:)는 번들 캐시를 공유하므로 원본을 직접 변형하지 않는다.
    private static let grainTileImage: NSImage = {
        guard let base = (NSImage(named: "HanjiGrain")?.copy() as? NSImage) else {
            timelineLog.fault("HanjiGrain 텍스처 로드 실패 — 결 오버레이 없이 렌더링됨 (번들 리소스 누락 의심)")
            return NSImage()
        }
        base.size = NSSize(width: HanjiTheme.grainTileSize, height: HanjiTheme.grainTileSize)
        return base
    }()

    var body: some View {
        ZStack {
            // 1) 바탕색, 2) 카드들, 3) 텍스트 — 순서대로 아래 레이어
            content
            // 4) 맨 위 결 오버레이 — 패널 전체를 덮는다 (tokens.md 레이어 순서)
            grainOverlay
                .allowsHitTesting(false)
        }
        .background(paper)
        .foregroundStyle(ink)
        .task { await model.load() }
        .onChange(of: model.isSearching) {
            searchFieldFocused = model.isSearching
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // 헤더 — 검색 바보다 위, 패널 최상단.
            HeaderView(
                filterName: model.filterName,
                onSearch: { model.isSearching = true },
                onTray: { model.toggleDrawer() },
                onSettings: onOpenSettings)
            Divider()
            // [Task 23] 1차 폴더 전환 바 — 폴더가 하나도 없으면 통째로 숨겨 타임라인 정체성을
            // 그대로 유지한다. 드로어보다 위(이 바 아래에서 드로어가 오버레이됨)에 둔다.
            if !model.folders.isEmpty {
                FolderChipBar(model: model)
                Divider()
            }
            // 헤더 아래 전체(검색바·타임라인·컴포저) 위에 드로어를 오버레이로 얹는다.
            // 그레인 오버레이(body의 바깥 ZStack)는 이 ZStack보다 한 겹 더 위에 있으므로
            // "패널 최상단 유지" 원칙대로 드로어 위에도 그대로 덮인다.
            ZStack(alignment: .top) {
                mainArea
                if model.isDrawerOpen {
                    DrawerView(model: model)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var mainArea: some View {
        VStack(spacing: 0) {
            if model.isSearching {
                searchBar
                Divider()
            }
            if model.displayedNotes.isEmpty && !model.isSearching && model.draft.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: HanjiTheme.cardSpacing) {
                            ForEach(groupedByDay(), id: \.day) { group in
                                DaySeparator(label: group.label)
                                ForEach(group.notes) { note in
                                    NoteCardView(note: note, model: model)
                                        .id(note.id)
                                        // 카드 안착 모션 — 전송 시 아래에서 사뿐히 올라온다.
                                        // TimelineModel.submit/delete가 HanjiTheme.motion으로 감싸며,
                                        // 그 안에서 '동작 줄이기' 존중 여부를 이미 판단한다.
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity))
                                }
                            }
                        }
                        .padding(HanjiTheme.panelHorizontalMargin)
                    }
                    .onChange(of: model.displayedNotes.count) {
                        if let last = model.displayedNotes.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            composerArea
        }
    }

    /// [Task 24] 컴포저 필드 구분 — 이전에는 배경이 패널 바탕과 같아 "메모 작성 중"이라는
    /// 사실이 시각적으로 드러나지 않았다(QA 지적). card 톤 배경 + inkSoft 25% 테두리로
    /// 감싸고, 비어 있을 때 플레이스홀더를 얹는다. 왼쪽 체크리스트 버튼은 현재 줄 시작에
    /// "[] " 마커를 삽입한다(ChecklistParser가 기대하는 정확한 문자열).
    private var composerArea: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ComposerIconButton(systemName: "checklist", inkSoft: inkSoft, ink: ink) {
                composerCommands.insertChecklistMarker()
            }
            ZStack(alignment: .topLeading) {
                if model.draft.isEmpty {
                    // ComposerTextView의 textContainerInset(멀티라인: width 12 · height 10)과
                    // 정렬을 맞춰 타이핑된 첫 글자 자리와 겹치도록 한다. leading은 12(인셋)+
                    // 5(NSTextContainer 기본 lineFragmentPadding, ComposerTextView가 건드리지
                    // 않는 값)만큼 보정한 17 — 그렇지 않으면 플레이스홀더가 실제 타이핑 위치보다
                    // 5pt 왼쪽에 떠 보인다 (리뷰 지적, Fix round 1).
                    Text("새 메모…")
                        .font(HanjiTheme.bodyFont())
                        .foregroundStyle(inkSoft)
                        .padding(.leading, 17)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                }
                ComposerTextView(
                    text: $model.draft,
                    font: HanjiTheme.bodyNSFont(),
                    onSubmit: { Task { await model.submit() } },
                    commands: composerCommands)
            }
            .frame(minHeight: 44, maxHeight: 120)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(card))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(inkSoft.opacity(0.25), lineWidth: 1))
        }
        .padding(8)
    }

    /// 검색 바 — tokens.md "검색 입력 Pretendard 14pt". 활성 태그 필터는 기존 태그 칩과
    /// 같은 스타일(r3 라운드 사각형 · 12% 알파, Task 12 review fix)로 통일해 보여준다.
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").opacity(0.5)
            TextField("검색 (초성 가능)", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(HanjiTheme.uiFont(size: 14))
                .focused($searchFieldFocused)
            if let tag = model.activeTag {
                let color = HanjiTheme.tagColor(tag, dark: scheme == .dark)
                Text("#\(tag)")
                    .font(HanjiTheme.uiFont(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(color.opacity(HanjiTheme.tagChipAlpha)))
                    .foregroundStyle(color)
            }
        }
        .padding(10)
    }

    private var grainOverlay: some View {
        Rectangle()
            .fill(grainTint)
            .mask(
                Image(nsImage: Self.grainTileImage)
                    .resizable(resizingMode: .tile)
            )
            .opacity(grainOpacity)
    }

    private struct DayGroup {
        let day: String
        let label: String
        let notes: [Note]
    }

    private func groupedByDay() -> [DayGroup] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "M월 d일"
        df.locale = Locale(identifier: "ko_KR")
        var groups: [DayGroup] = []
        for note in model.displayedNotes {
            let label: String
            if cal.isDateInToday(note.createdAt) { label = "오늘" }
            else if cal.isDateInYesterday(note.createdAt) { label = "어제" }
            else { label = df.string(from: note.createdAt) }
            if groups.last?.label == label {
                let last = groups.removeLast()
                groups.append(DayGroup(day: last.day, label: label, notes: last.notes + [note]))
            } else {
                groups.append(DayGroup(day: label, label: label, notes: [note]))
            }
        }
        return groups
    }
}

struct DaySeparator: View {
    let label: String
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).opacity(0.15)
            Text(label).font(HanjiTheme.uiFont(size: 11, weight: .semibold)).opacity(0.6).fixedSize()
            Rectangle().frame(height: 1).opacity(0.15)
        }
        // 렌더링된 이음매 여백은 승인 토큰(22/12)과 일치해야 한다. 이 뷰는
        // LazyVStack(spacing: HanjiTheme.cardSpacing) 안에 놓이므로 스택이 위·아래에
        // 이미 cardSpacing만큼을 더해준다 — 그 몫을 토큰에서 빼서 나머지만 패딩한다.
        // 22 - 8 = 14 (위), 12 - 8 = 4 (아래)
        .padding(.top, HanjiTheme.seamMarginTop - HanjiTheme.cardSpacing)
        .padding(.bottom, HanjiTheme.seamMarginBottom - HanjiTheme.cardSpacing)
    }
}

/// [Task 24] 컴포저 왼쪽 체크리스트 버튼 — HeaderView.HeaderIconButton과 같은 관례
/// (SF Symbol template, 13pt, inkSoft 기본, 호버 시 ink로 전환, 22x22 히트 영역).
private struct ComposerIconButton: View {
    let systemName: String
    let inkSoft: Color
    let ink: Color
    let action: () -> Void

    @State private var isHovering = false

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
