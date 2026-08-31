import SwiftUI
import AppKit
import Domain

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
        guard let base = (NSImage(named: "HanjiGrain")?.copy() as? NSImage) else { return NSImage() }
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
        .padding(.top, HanjiTheme.seamMarginTop / 2)
        .padding(.bottom, HanjiTheme.seamMarginBottom / 2)
    }
}

// Task 12에서 완성 — 걷는 골격용 최소 버전
struct NoteCardView: View {
    let note: Note
    let model: TimelineModel
    @Environment(\.colorScheme) private var scheme

    private var card: Color { scheme == .dark ? HanjiTheme.cardDark : HanjiTheme.cardLight }

    var body: some View {
        Text(note.content)
            .font(HanjiTheme.bodyFont())
            .lineSpacing((HanjiTheme.bodyLineHeightMultiple - 1) * 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, HanjiTheme.cardPaddingV)
            .padding(.horizontal, HanjiTheme.cardPaddingH)
            .background(RoundedRectangle(cornerRadius: HanjiTheme.cardRadius).fill(card))
    }
}
