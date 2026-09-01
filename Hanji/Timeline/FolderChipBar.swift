import SwiftUI
import Domain

/// [v1.2 Task 23] 헤더 아래 상시 노출되는 1차 폴더 전환 바 — 탭 한 번으로 전체/폴더/미분류를
/// 오간다. 서랍(DrawerView)은 폴더 CRUD·태그 전용으로 남고, 이 바가 주 전환 수단이 된다.
/// model.folders가 비어 있으면(폴더가 하나도 없으면) TimelineView가 이 뷰 자체를 렌더링하지
/// 않는다 — 데이터 로드는 새로 추가하지 않고 기존 경로(load()→loadFolderData, 드로어 CRUD
/// 후 재로드)를 그대로 신뢰한다.
struct FolderChipBar: View {
    let model: TimelineModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FolderChip(name: "전체", isSelected: model.folderFilter == .all) {
                    model.folderFilter = .all
                }
                // sortOrder 순 — model.folders는 repo에서 이미 그 순서로 온다(정렬 재수행 금지).
                ForEach(model.folders) { folder in
                    FolderChip(name: folder.name, isSelected: model.folderFilter == .folder(folder.id)) {
                        model.folderFilter = .folder(folder.id)
                    }
                }
                // 카운트와 무관하게 항상 표시.
                FolderChip(name: "미분류", isSelected: model.folderFilter == .unfiled) {
                    model.folderFilter = .unfiled
                }
            }
            .padding(.horizontal, HanjiTheme.panelHorizontalMargin)
            .padding(.vertical, 6)
        }
    }
}

/// 칩 하나 — DrawerRow·태그 칩(NoteCardView.tagChip)과 동일한 선택/호버 관례를 따른다:
/// 선택 시 semibold + jjok 전경 + jjokWash 배경, 비선택 inkSoft + 배경 없음,
/// 호버 시 inkSoft.opacity(0.08) 배경.
private struct FolderChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    private var isDark: Bool { scheme == .dark }
    private var inkSoft: Color { isDark ? HanjiTheme.inkSoftDark : HanjiTheme.inkSoftLight }
    private var jjok: Color { isDark ? HanjiTheme.jjokDark : HanjiTheme.jjokLight }
    private var jjokWash: Color { isDark ? HanjiTheme.jjokWashDark : HanjiTheme.jjokWashLight }

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(HanjiTheme.uiFont(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? jjok : inkSoft)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? jjokWash : (isHovering ? inkSoft.opacity(0.08) : Color.clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
