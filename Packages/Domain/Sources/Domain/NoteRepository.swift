import Foundation

public protocol NoteRepository: Sendable {
    /// upsert — 같은 id가 있으면 갱신. 태그·검색 색인도 트랜잭션으로 함께 갱신된다.
    func save(_ note: Note) async throws
    func delete(id: UUID) async throws
    func note(id: UUID) async throws -> Note?
    /// createdAt 내림차순 페이지. before가 nil이면 최신부터.
    func timeline(before: Date?, limit: Int) async throws -> [Note]
    func search(_ query: SearchQuery, limit: Int) async throws -> [Note]
    /// 사전순 정렬된 전체 태그 목록
    func allTags() async throws -> [String]
    /// createdAt 오름차순 전체 (내보내기용)
    func exportAll() async throws -> [Note]
}
