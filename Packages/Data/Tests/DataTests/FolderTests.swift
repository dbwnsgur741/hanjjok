import XCTest
import GRDB
import Domain
@testable import Data

final class FolderTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hanji-folder-test-\(UUID().uuidString)")
            .appendingPathComponent("test.sqlite")
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }
    private func makeRepo() throws -> GRDBNoteRepository {
        try GRDBNoteRepository(databaseURL: tempURL)
    }
    private func note(_ content: String, at date: Date = Date(), folderId: UUID? = nil) -> Note {
        Note(id: UUID(), content: content, createdAt: date, updatedAt: nil, folderId: folderId)
    }
    private func folder(_ name: String, sortOrder: Int = 0, createdAt: Date = Date()) -> Folder {
        Folder(id: UUID(), name: name, sortOrder: sortOrder, createdAt: createdAt)
    }

    // MARK: - CRUD

    func test_폴더_저장_후_목록에_나타난다() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        let all = try await repo.folders()
        XCTAssertEqual(all, [f])
    }

    func test_폴더_저장은_upsert_이름변경() async throws {
        let repo = try makeRepo()
        var f = folder("업무")
        try await repo.saveFolder(f)
        f.name = "회사"
        try await repo.saveFolder(f)
        let all = try await repo.folders()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "회사")
    }

    func test_폴더_목록은_sortOrder_그다음_createdAt_순() async throws {
        let repo = try makeRepo()
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = Date(timeIntervalSince1970: 2_000)
        let a = Folder(id: UUID(), name: "A", sortOrder: 1, createdAt: t1)
        let b = Folder(id: UUID(), name: "B", sortOrder: 0, createdAt: t0)
        let c = Folder(id: UUID(), name: "C", sortOrder: 0, createdAt: t1)
        try await repo.saveFolder(a)
        try await repo.saveFolder(b)
        try await repo.saveFolder(c)
        let all = try await repo.folders()
        XCTAssertEqual(all.map(\.name), ["B", "C", "A"])  // sortOrder 0(B,C: createdAt순) 다음 sortOrder 1(A)
    }

    // MARK: - 삭제 → SET NULL

    func test_폴더_삭제시_소속_메모는_미분류로_전환된다() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        let n = note("메모", folderId: f.id)
        try await repo.save(n)

        try await repo.deleteFolder(id: f.id)

        let fetched = try await repo.note(id: n.id)
        XCTAssertNotNil(fetched)
        XCTAssertNil(fetched?.folderId)
    }

    func test_폴더_삭제_후_폴더_목록에서_사라진다() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        try await repo.deleteFolder(id: f.id)
        let all = try await repo.folders()
        XCTAssertEqual(all, [])
    }

    // MARK: - timeline 필터

    func test_timeline_filter_all_은_모든_메모를_반환() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        try await repo.save(note("미분류1"))
        try await repo.save(note("폴더1", folderId: f.id))

        let all = try await repo.timeline(filter: .all, before: nil, limit: 10)
        XCTAssertEqual(Set(all.map(\.content)), Set(["미분류1", "폴더1"]))
    }

    func test_timeline_filter_unfiled_은_미분류만_반환() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        try await repo.save(note("미분류1"))
        try await repo.save(note("폴더1", folderId: f.id))

        let unfiled = try await repo.timeline(filter: .unfiled, before: nil, limit: 10)
        XCTAssertEqual(unfiled.map(\.content), ["미분류1"])
    }

    func test_timeline_filter_folder_은_해당_폴더_메모만_반환() async throws {
        let repo = try makeRepo()
        let f1 = folder("업무")
        let f2 = folder("개인")
        try await repo.saveFolder(f1)
        try await repo.saveFolder(f2)
        try await repo.save(note("미분류1"))
        try await repo.save(note("폴더1", folderId: f1.id))
        try await repo.save(note("폴더2", folderId: f2.id))

        let filtered = try await repo.timeline(filter: .folder(f1.id), before: nil, limit: 10)
        XCTAssertEqual(filtered.map(\.content), ["폴더1"])
    }

    func test_timeline_filter는_before와_AND_결합된다() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        let t0 = Date(timeIntervalSince1970: 1_000)
        let t1 = Date(timeIntervalSince1970: 2_000)
        try await repo.save(note("옛날", at: t0, folderId: f.id))
        try await repo.save(note("최근", at: t1, folderId: f.id))

        let result = try await repo.timeline(filter: .folder(f.id), before: t1, limit: 10)
        XCTAssertEqual(result.map(\.content), ["옛날"])
    }

    // MARK: - search 필터 (폴더 내 검색)

    func test_search_필터_폴더_내_검색() async throws {
        let repo = try makeRepo()
        let f1 = folder("업무")
        let f2 = folder("개인")
        try await repo.saveFolder(f1)
        try await repo.saveFolder(f2)
        try await repo.save(note("사이드노트 업무용", folderId: f1.id))
        try await repo.save(note("사이드노트 개인용", folderId: f2.id))
        try await repo.save(note("사이드노트 미분류"))

        let hits = try await repo.search(.parse("사이드"), filter: .folder(f1.id), limit: 10)
        XCTAssertEqual(hits.map(\.content), ["사이드노트 업무용"])
    }

    func test_search_필터_unfiled() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        try await repo.save(note("사이드노트 업무용", folderId: f.id))
        try await repo.save(note("사이드노트 미분류"))

        let hits = try await repo.search(.parse("사이드"), filter: .unfiled, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["사이드노트 미분류"])
    }

    func test_search_필터_all_은_폴더_구분없이_검색() async throws {
        let repo = try makeRepo()
        let f = folder("업무")
        try await repo.saveFolder(f)
        try await repo.save(note("사이드노트 업무용", folderId: f.id))
        try await repo.save(note("사이드노트 미분류"))

        let hits = try await repo.search(.parse("사이드"), filter: .all, limit: 10)
        XCTAssertEqual(hits.count, 2)
    }

    // MARK: - counts

    func test_folderCounts는_전체_미분류_폴더별_개수를_반환() async throws {
        let repo = try makeRepo()
        let f1 = folder("업무")
        let f2 = folder("개인")
        try await repo.saveFolder(f1)
        try await repo.saveFolder(f2)
        try await repo.save(note("미분류1"))
        try await repo.save(note("미분류2"))
        try await repo.save(note("업무1", folderId: f1.id))
        try await repo.save(note("업무2", folderId: f1.id))
        try await repo.save(note("업무3", folderId: f1.id))
        try await repo.save(note("개인1", folderId: f2.id))

        let counts = try await repo.folderCounts()
        XCTAssertEqual(counts.all, 6)
        XCTAssertEqual(counts.unfiled, 2)
        XCTAssertEqual(counts.byFolder[f1.id], 3)
        XCTAssertEqual(counts.byFolder[f2.id], 1)
    }

    func test_folderCounts_폴더에_메모가_없으면_byFolder에_나타나지_않는다() async throws {
        let repo = try makeRepo()
        let f = folder("빈폴더")
        try await repo.saveFolder(f)
        let counts = try await repo.folderCounts()
        XCTAssertEqual(counts.all, 0)
        XCTAssertEqual(counts.unfiled, 0)
        XCTAssertNil(counts.byFolder[f.id])
    }

    func test_tagCounts는_태그별_개수를_사전순으로_반환() async throws {
        let repo = try makeRepo()
        try await repo.save(note("#업무 회의"))
        try await repo.save(note("#업무 점심"))
        try await repo.save(note("#아이디어 메모"))

        let counts = try await repo.tagCounts()
        XCTAssertEqual(counts, [TagCount(tag: "아이디어", count: 1), TagCount(tag: "업무", count: 2)])
    }

    // MARK: - 마이그레이션 무손실 (v1 → v2)

    /// 구버전(v1까지만 적용된) DB 파일을 직접 만들어 실제 업그레이드 상황을 시뮬레이션한다.
    /// (테스트 리소스로 저장된 실제 v1 파일이 없으므로, v1 전용 마이그레이터로 그 상태를 재현한다.)
    func test_v1_DB를_v2로_마이그레이션하면_기존_노트가_보존되고_folder_id는_NULL이다() async throws {
        var v1Migrator = DatabaseMigrator()
        v1Migrator.registerMigration("v1") { db in
            try db.create(table: "note") { t in
                t.primaryKey("id", .text)
                t.column("content", .text).notNull()
                t.column("created_at", .datetime).notNull().indexed()
                t.column("updated_at", .datetime)
                t.column("jamo", .text).notNull()
                t.column("choseong", .text).notNull()
            }
            try db.create(table: "note_tag") { t in
                t.column("note_id", .text).notNull().indexed()
                    .references("note", onDelete: .cascade)
                t.column("tag", .text).notNull().indexed()
                t.primaryKey(["note_id", "tag"])
            }
        }

        let existingId = UUID()
        do {
            try FileManager.default.createDirectory(
                at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let pool = try DatabasePool(path: tempURL.path)
            try v1Migrator.migrate(pool)
            try await pool.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO note (id, content, created_at, jamo, choseong)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [existingId.uuidString, "v1 시절 메모",
                                Date().timeIntervalSinceReferenceDate, "", ""])
            }
        }

        // 실제 앱 마이그레이터(v1+v2)로 다시 연다 — v2가 무손실로 적용되어야 한다.
        let repo = try GRDBNoteRepository(databaseURL: tempURL)
        let fetched = try await repo.note(id: existingId)
        XCTAssertEqual(fetched?.content, "v1 시절 메모")
        XCTAssertNil(fetched?.folderId)

        // 마이그레이션 후 폴더 배정도 정상 동작해야 한다.
        let f = folder("새폴더")
        try await repo.saveFolder(f)
        var updated = fetched!
        updated.folderId = f.id
        try await repo.save(updated)
        let refetched = try await repo.note(id: existingId)
        XCTAssertEqual(refetched?.folderId, f.id)
    }

    func test_같은_파일_재오픈해도_folder_id_기본값은_NULL_유지() async throws {
        let n = note("재오픈 확인")
        do {
            let repo = try makeRepo()
            try await repo.save(n)
        }
        let reopened = try GRDBNoteRepository(databaseURL: tempURL)
        let fetched = try await reopened.note(id: n.id)
        XCTAssertEqual(fetched?.content, "재오픈 확인")
        XCTAssertNil(fetched?.folderId)
    }
}
