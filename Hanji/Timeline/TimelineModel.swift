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
}
