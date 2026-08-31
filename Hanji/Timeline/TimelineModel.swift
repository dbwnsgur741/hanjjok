import Foundation
import Observation
import os
import Domain

@Observable @MainActor
final class TimelineModel {
    private let repo: any NoteRepository
    private let log = Logger(subsystem: "kr.hurdlers.Hanji", category: "timeline")
    private var undoStack: [Note] = []

    var notes: [Note] = []       // 표시용 — createdAt 오름차순 (아래가 최신)
    var draft = ""

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

    init(repo: any NoteRepository) {
        self.repo = repo
    }

    func load() async {
        do {
            notes = try await repo.timeline(before: nil, limit: 300).reversed()
        } catch {
            log.error("타임라인 로드 실패: \(error)")
        }
    }

    func submit() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = Note(id: UUID(), content: text, createdAt: Date(), updatedAt: nil)
        do {
            try await repo.save(note)
            notes.append(note)
            draft = ""
        } catch {
            log.error("저장 실패: \(error)")
        }
    }

    func delete(_ note: Note) async {
        do {
            try await repo.delete(id: note.id)
            notes.removeAll { $0.id == note.id }
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
                self.searchResults = try await self.repo.search(query, limit: 200).reversed()
            } catch {
                self.log.error("검색 실패: \(error)")
            }
        }
    }
}
