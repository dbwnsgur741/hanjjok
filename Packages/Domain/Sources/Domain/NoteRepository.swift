import Foundation

public protocol NoteRepository: Sendable {
    /// upsert — 같은 id가 있으면 갱신. 태그·검색 색인도 트랜잭션으로 함께 갱신된다.
    func save(_ note: Note) async throws
    func delete(id: UUID) async throws
    func note(id: UUID) async throws -> Note?
    /// createdAt 내림차순 페이지. before가 nil이면 최신부터. filter가 folder_id 조건과 AND 결합된다.
    func timeline(filter: FolderFilter, before: Date?, limit: Int) async throws -> [Note]
    /// filter가 folder_id 조건과 AND 결합된다 (폴더 내 검색 지원).
    func search(_ query: SearchQuery, filter: FolderFilter, limit: Int) async throws -> [Note]
    /// 사전순 정렬된 전체 태그 목록
    func allTags() async throws -> [String]
    /// createdAt 오름차순 전체 (내보내기용)
    func exportAll() async throws -> [Note]

    // MARK: - [v1.1] 폴더

    /// sortOrder 오름차순, 동률이면 createdAt 오름차순.
    func folders() async throws -> [Folder]
    /// upsert — 생성·이름변경·정렬을 모두 처리한다.
    func saveFolder(_ folder: Folder) async throws
    /// 소속 메모는 folder_id가 NULL(미분류)로 전환된다 (ON DELETE SET NULL).
    func deleteFolder(id: UUID) async throws
    func folderCounts() async throws -> FolderCounts
    func tagCounts() async throws -> [TagCount]
}
