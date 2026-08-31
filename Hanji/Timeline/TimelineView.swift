import SwiftUI
import AppKit
import Domain
import os

private let timelineLog = Logger(subsystem: "kr.hurdlers.Hanji", category: "timeline")

struct TimelineView: View {
    @Bindable var model: TimelineModel
    @Environment(\.colorScheme) private var scheme

    private var paper: Color { scheme == .dark ? HanjiTheme.paperDark : HanjiTheme.paperLight }
    private var ink: Color { scheme == .dark ? HanjiTheme.inkDark : HanjiTheme.inkLight }
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
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: HanjiTheme.cardSpacing) {
                        ForEach(groupedByDay(), id: \.day) { group in
                            DaySeparator(label: group.label)
                            ForEach(group.notes) { note in
                                NoteCardView(note: note, model: model)
                                    .id(note.id)
                            }
                        }
                    }
                    .padding(HanjiTheme.panelHorizontalMargin)
                }
                .onChange(of: model.notes.count) {
                    if let last = model.notes.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            Divider()
            ComposerTextView(
                text: $model.draft,
                font: HanjiTheme.bodyNSFont(),
                onSubmit: { Task { await model.submit() } })
                .frame(minHeight: 44, maxHeight: 120)
                .padding(8)
        }
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
        for note in model.notes {
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
