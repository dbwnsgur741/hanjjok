import Foundation
import Observation
import os
import Domain

@Observable @MainActor
final class TimelineModel {
    private let repo: any NoteRepository
    private let log = Logger(subsystem: "kr.hurdlers.Hanjjok", category: "timeline")
    private var undoStack: [Note] = []

    var notes: [Note] = []       // 표시용 — createdAt 오름차순 (아래가 최신)
    var draft = ""

    // MARK: - 인라인 수정 (QA r3)

    /// 현재 인라인 수정 중인 카드의 note.id — nil이면 아무 카드도 수정 중이 아니다.
    /// 수정 중 상태는 앱 전체 1개(스펙 §3, QA r3). NoteCardView.isEditing이 이 값을
    /// 참조해 파생하며, 예전처럼 카드마다 로컬 @State로 관리하면 여러 카드가 동시에
    /// 편집 가능해지는 버그가 있었다(QA r3 ⑤-b).
    var editingNoteID: UUID?

    // MARK: - 검색 (Task 13)

    var isSearching = false
    var searchText = "" {
        didSet { scheduleSearch() }
    }
    var searchResults: [Note] = []   // 표시용 — createdAt 오름차순 (타임라인과 동일 방향)
    var activeTag: String?
    private var searchTask: Task<Void, Never>?

    /// 검색 중이거나 태그 필터가 걸려 있으면 검색 결과를, 아니면 전체 타임라인을 보여준다.
    var displayedNotes: [Note] {
        isSearching || activeTag != nil ? searchResults : notes
    }
    var currentSearchText: SearchText? {
        SearchQuery.parse(searchText).text
    }

    // MARK: - 폴더·서랍 (Task 18)

    /// 타임라인·검색에 적용하는 폴더 스코프. 변경 시 타임라인을 재로드하고, 검색/태그 필터
    /// 중이면 그 조건 그대로 재검색한다(폴더 내 검색 — NoteRepository가 filter를
    /// AND 결합해 지원).
    var folderFilter: FolderFilter = .all {
        didSet {
            guard folderFilter != oldValue, !suppressFilterReload else { return }
            Task { [weak self] in await self?.applyFolderFilterChange() }
        }
    }
    /// deleteFolder(_:)가 folderFilter를 내부적으로 .all로 되돌릴 때만 켜는 억제 플래그.
    /// 그 경로는 뒤이어 자신의 단일 재로드(load() + 필요 시 scheduleSearch())를 직접
    /// 수행하므로, 억제하지 않으면 didSet이 띄우는 또 다른 재로드 Task와 경쟁하며
    /// timeline(.all) 조회가 중복 실행된다(리뷰 지적 — Task 18 fix).
    private var suppressFilterReload = false
    var folders: [Folder] = []
    var counts: FolderCounts?
    var tagCounts: [TagCount] = []
    /// 드로어 열림 상태. true로 바뀔 때만 폴더·카운트를 재로드해 최신화한다.
    var isDrawerOpen = false {
        didSet {
            guard isDrawerOpen, isDrawerOpen != oldValue else { return }
            Task { [weak self] in await self?.loadFolderData() }
        }
    }

    /// 헤더에 표시할 현재 필터명 — 태그 필터가 있으면 그것을 우선 표시(검색 중에도 유지),
    /// 없으면 폴더 스코프(전체/미분류/폴더명)를 표시한다.
    var filterName: String {
        if let tag = activeTag { return "#\(tag)" }
        switch folderFilter {
        case .all: return "전체"
        case .unfiled: return "미분류"
        case .folder(let id): return folders.first(where: { $0.id == id })?.name ?? "폴더"
        }
    }

    init(repo: any NoteRepository) {
        self.repo = repo
    }

    func load() async {
        do {
            notes = try await repo.timeline(filter: folderFilter, before: nil, limit: 300).reversed()
        } catch {
            log.error("타임라인 로드 실패: \(error)")
        }
        await loadFolderData()
    }

    /// [QA r4 ①] 저장 성공(가드 통과 + repo.save 성공) 시에만 true를 돌려준다 — TimelineView의
    /// sendFromComposer()가 이 값으로 "컴포저를 비워도 되는가"를 판단한다. `@discardableResult`라
    /// 반환값을 무시하는 기존 호출부(있다면)는 그대로 컴파일된다.
    @discardableResult
    func submit() async -> Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let note = Note(id: UUID(), content: text, createdAt: Date(), updatedAt: nil)
        do {
            try await repo.save(note)
            HanjjokTheme.motion { notes.append(note) }
            draft = ""
            return true
        } catch {
            log.error("저장 실패: \(error)")
            return false
        }
    }

    func delete(_ note: Note) async {
        do {
            try await repo.delete(id: note.id)
            HanjjokTheme.motion { notes.removeAll { $0.id == note.id } }
            undoStack.append(note)
        } catch {
            log.error("삭제 실패: \(error)")
        }
    }

    func undoDelete() async {
        guard let note = undoStack.popLast() else { return }
        do {
            try await repo.save(note)
            let idx = notes.firstIndex { $0.createdAt > note.createdAt } ?? notes.endIndex
            notes.insert(note, at: idx)
        } catch {
            log.error("삭제 취소 실패: \(error)")
        }
    }

    func update(_ note: Note, content: String) async {
        var updated = note
        updated.content = content
        updated.updatedAt = Date()
        do {
            try await repo.save(updated)
            if let i = notes.firstIndex(where: { $0.id == note.id }) { notes[i] = updated }
        } catch {
            log.error("수정 실패: \(error)")
        }
    }

    // MARK: - 폴더 이동 (Task 19)

    /// 호버 아이콘·컨텍스트 메뉴의 "폴더로 이동" — note.folderId를 갱신해 저장하고,
    /// 현재 보고 있는 폴더 스코프(folderFilter)에서 벗어나면 목록(notes/searchResults)에서
    /// 제거한다. 폴더별 카운트(counts)는 여기서 갱신하지 않는다 — 다음 드로어 오픈 시
    /// isDrawerOpen didSet이 loadFolderData()로 재로드하는 것으로 충분하다 (Task 18).
    func move(note: Note, to folderId: UUID?) async {
        var updated = note
        updated.folderId = folderId
        do {
            try await repo.save(updated)
            applyMoveResult(updated)
        } catch {
            log.error("폴더 이동 실패: \(error)")
        }
    }

    private func applyMoveResult(_ updated: Note) {
        let stillMatches = matchesFolderFilter(updated.folderId)
        if let i = notes.firstIndex(where: { $0.id == updated.id }) {
            if stillMatches { notes[i] = updated }
            else { HanjjokTheme.motion { notes.remove(at: i) } }
        }
        if let i = searchResults.firstIndex(where: { $0.id == updated.id }) {
            if stillMatches { searchResults[i] = updated }
            else { HanjjokTheme.motion { searchResults.remove(at: i) } }
        }
    }

    private func matchesFolderFilter(_ folderId: UUID?) -> Bool {
        switch folderFilter {
        case .all: return true
        case .unfiled: return folderId == nil
        case .folder(let id): return folderId == id
        }
    }

    // MARK: - 검색 (Task 13)

    /// 태그 칩 클릭 시 호출 — 해당 태그로 필터링하며 라이브 검색을 트리거한다.
    func setTagFilter(_ tag: String?) {
        activeTag = tag
        scheduleSearch()
    }

    func exitSearch() {
        // searchText를 마지막에 비운다: didSet(scheduleSearch)이 isSearching/activeTag가
        // 이미 초기화된 뒤에 실행되어야 안 그러면 빈 텍스트 + 옛 태그로 스친 검색이
        // 150ms 뒤 뒤늦게 도착해 방금 비운 searchResults를 덮어쓴다.
        searchTask?.cancel()
        isSearching = false
        activeTag = nil
        searchText = ""
        searchResults = []
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard isSearching || activeTag != nil else { return }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled else { return }
            var query = SearchQuery.parse(self.searchText)
            if let tag = self.activeTag, !query.tags.contains(tag) {
                query = SearchQuery(tags: query.tags + [tag], text: query.text)
            }
            do {
                // 검색 결과도 타임라인처럼 오래된 것 위, 최신 아래로 표시
                self.searchResults = try await self.repo.search(
                    query, filter: self.folderFilter, limit: 200
                ).reversed()
            } catch {
                self.log.error("검색 실패: \(error)")
            }
        }
    }

    // MARK: - 폴더 CRUD (Task 18)

    func createFolder(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (folders.map(\.sortOrder).max() ?? -1) + 1
        let folder = Folder(id: UUID(), name: trimmed, sortOrder: nextOrder, createdAt: Date())
        do {
            try await repo.saveFolder(folder)
            await loadFolderData()
        } catch {
            log.error("폴더 생성 실패: \(error)")
        }
    }

    func renameFolder(_ folder: Folder, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = folder
        updated.name = trimmed
        do {
            try await repo.saveFolder(updated)
            await loadFolderData()
        } catch {
            log.error("폴더 이름 변경 실패: \(error)")
        }
    }

    func deleteFolder(_ folder: Folder) async {
        do {
            try await repo.deleteFolder(id: folder.id)
            // 삭제된 폴더를 보고 있었다면 전체 스코프로 되돌린다. 이 대입이 didSet의 자동
            // 재로드 Task를 또 띄우지 않도록 suppressFilterReload로 억제하고, 아래 단일
            // 경로(load() + 필요 시 scheduleSearch())만이 유일한 재로드가 되게 한다 —
            // 그렇지 않으면 동일한 timeline(.all) 조회가 두 번(경쟁 상태로) 실행된다.
            if case .folder(let id) = folderFilter, id == folder.id {
                suppressFilterReload = true
                folderFilter = .all
                suppressFilterReload = false
            }
            await load()
            if isSearching || activeTag != nil { scheduleSearch() }
        } catch {
            log.error("폴더 삭제 실패: \(error)")
        }
    }

    /// 서랍 토글 — HanjjokTheme.motion으로 ≤200ms 슬라이드 애니메이션(동작 줄이기 존중)을 적용한다.
    func toggleDrawer() {
        HanjjokTheme.motion { isDrawerOpen.toggle() }
    }

    /// 스크림 탭·행 선택·Esc 등 "닫기"만 하는 경로에서 공용으로 쓰는 헬퍼.
    func closeDrawer() {
        guard isDrawerOpen else { return }
        HanjjokTheme.motion { isDrawerOpen = false }
    }

    private func applyFolderFilterChange() async {
        do {
            notes = try await repo.timeline(filter: folderFilter, before: nil, limit: 300).reversed()
        } catch {
            log.error("타임라인 로드 실패: \(error)")
        }
        if isSearching || activeTag != nil { scheduleSearch() }
    }

    private func loadFolderData() async {
        do {
            folders = try await repo.folders()
            counts = try await repo.folderCounts()
            tagCounts = try await repo.tagCounts()
        } catch {
            log.error("폴더 데이터 로드 실패: \(error)")
        }
    }
}
