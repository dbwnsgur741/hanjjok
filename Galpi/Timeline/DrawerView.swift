import SwiftUI
import AppKit
import Domain

/// [v1.1 Task 18] 서랍 드로어 — 헤더 tray 아이콘으로 여닫는 폴더·태그 목록 오버레이.
/// TimelineView가 헤더 아래(검색바·타임라인·컴포저) 영역을 감싸는 ZStack 안에 이 뷰를
/// 조건부로 얹어 위→아래로 슬라이드시킨다. 그레인 오버레이는 그보다 한 겹 더 바깥 ZStack의
/// 맨 위 레이어(TimelineView.body)이므로 "패널 최상단 유지" 원칙대로 드로어 위에도 그대로 덮인다.
struct DrawerView: View {
    let model: TimelineModel
    @Environment(\.colorScheme) private var scheme

    @State private var isAddingFolder = false
    @State private var newFolderName = ""

    @State private var renamingFolderID: UUID?
    @State private var renameText = ""

    private var isDark: Bool { scheme == .dark }
    private var card: Color { isDark ? GalpiTheme.cardDark : GalpiTheme.cardLight }
    private var ink: Color { isDark ? GalpiTheme.inkDark : GalpiTheme.inkLight }
    private var inkSoft: Color { isDark ? GalpiTheme.inkSoftDark : GalpiTheme.inkSoftLight }

    /// 이름 입력용 UI 폰트 — Pretendard 13pt, 로드 실패 시 시스템 폰트로 대체(GalpiTheme 관례).
    private var uiNSFont: NSFont {
        NSFont(name: FontName.pretendardRegular, size: 13) ?? .systemFont(ofSize: 13)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 배경 스크림 — 드로어 카드가 덮지 않는 나머지 영역을 탭하면 닫힌다.
            // ink 저알파로 "카드가 위에 떠 있다"는 느낌만 준다(먹빛 톤 유지, 순검정 금지 원칙).
            ink.opacity(0.14)
                .contentShape(Rectangle())
                .onTapGesture { model.closeDrawer() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                folderSection
                Divider().padding(.vertical, 4)
                tagSection
            }
            .padding(.vertical, 10)
            .background(card)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(ink)
    }

    // MARK: - 섹션 1: 폴더

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("폴더")
            DrawerRow(icon: "tray.full", name: "전체", count: model.counts?.all ?? 0,
                      isSelected: model.folderFilter == .all) {
                model.folderFilter = .all
                model.closeDrawer()
            }
            DrawerRow(icon: "questionmark.folder", name: "미분류", count: model.counts?.unfiled ?? 0,
                      isSelected: model.folderFilter == .unfiled) {
                model.folderFilter = .unfiled
                model.closeDrawer()
            }
            ForEach(model.folders) { folder in
                folderRow(folder)
            }
            newFolderRow
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: Folder) -> some View {
        if renamingFolderID == folder.id {
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(inkSoft).frame(width: 16)
                ComposerTextView(
                    text: $renameText,
                    font: uiNSFont,
                    onSubmit: { commitRename(folder) },
                    singleLine: true)
                    .frame(height: 20)
                    // 인라인 이름 변경 중 Esc는 이 필드만 취소한다(NoteCardView 인라인 수정과 동일 관례) —
                    // 드로어 자체는 닫히지 않는다.
                    .onExitCommand { renamingFolderID = nil }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
        } else {
            DrawerRow(icon: "folder", name: folder.name,
                      count: model.counts?.byFolder[folder.id] ?? 0,
                      isSelected: model.folderFilter == .folder(folder.id)) {
                model.folderFilter = .folder(folder.id)
                model.closeDrawer()
            }
            .contextMenu {
                Button("이름 변경") { beginRename(folder) }
                Button("삭제", role: .destructive) { confirmDelete(folder) }
            }
        }
    }

    @ViewBuilder
    private var newFolderRow: some View {
        if isAddingFolder {
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(inkSoft).frame(width: 16)
                ComposerTextView(
                    text: $newFolderName,
                    font: uiNSFont,
                    onSubmit: {
                        let name = newFolderName
                        newFolderName = ""   // 생성 후 초기화 — 필드는 열린 채로 다음 입력을 받는다.
                        Task { await model.createFolder(name: name) }
                    },
                    singleLine: true)
                    .frame(height: 20)
                    .onExitCommand { isAddingFolder = false; newFolderName = "" }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
        } else {
            Button {
                isAddingFolder = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").frame(width: 16)
                    Text("새 폴더")
                }
                .font(GalpiTheme.uiFont(size: 13))
                .foregroundStyle(inkSoft)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 섹션 2: 태그

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("태그")
            if model.tagCounts.isEmpty {
                Text("태그 없음")
                    .font(GalpiTheme.uiFont(size: 12))
                    .foregroundStyle(inkSoft)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            } else {
                ForEach(model.tagCounts, id: \.tag) { tc in
                    DrawerRow(icon: "number", name: tc.tag, count: tc.count,
                              isSelected: model.activeTag == tc.tag) {
                        // 기존 태그 칩(NoteCardView)과 동일한 필터 경로 재사용.
                        model.isSearching = true
                        model.setTagFilter(tc.tag)
                        model.closeDrawer()
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(GalpiTheme.uiFont(size: 11, weight: .semibold))
            .foregroundStyle(inkSoft)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    // MARK: - 액션

    private func beginRename(_ folder: Folder) {
        renameText = folder.name
        renamingFolderID = folder.id
    }

    private func commitRename(_ folder: Folder) {
        let name = renameText
        renamingFolderID = nil
        Task { await model.renameFolder(folder, to: name) }
    }

    @MainActor
    private func confirmDelete(_ folder: Folder) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "\"\(folder.name)\" 폴더를 삭제할까요?"
        alert.informativeText = "메모는 미분류로 이동합니다."
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        // LSUIElement 앱은 활성화하지 않으면 알림창이 키 윈도우가 되지 않을 수 있다
        // (GalpiApp.showExportError와 동일 이유).
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Task { await model.deleteFolder(folder) }
        }
    }
}

/// 공통 행 — 아이콘 + 이름 + 우측 정렬 카운트(tabular). 선택 시 jjok wash 배경, 호버 시 은은한 틴트.
private struct DrawerRow: View {
    let icon: String
    let name: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    private var isDark: Bool { scheme == .dark }
    private var inkSoft: Color { isDark ? GalpiTheme.inkSoftDark : GalpiTheme.inkSoftLight }
    private var jjok: Color { isDark ? GalpiTheme.jjokDark : GalpiTheme.jjokLight }
    private var jjokWash: Color { isDark ? GalpiTheme.jjokWashDark : GalpiTheme.jjokWashLight }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? jjok : inkSoft)
                    .frame(width: 16)
                Text(name)
                    .font(GalpiTheme.uiFont(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(count)")
                    .font(GalpiTheme.uiFont(size: 11).monospacedDigit())
                    .foregroundStyle(inkSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? jjokWash : (isHovering ? inkSoft.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
