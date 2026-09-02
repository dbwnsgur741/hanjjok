import XCTest
import Domain
@testable import Data

final class GRDBNoteRepositoryTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hanjjok-test-\(UUID().uuidString)")
            .appendingPathComponent("test.sqlite")
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }
    private func makeRepo() throws -> GRDBNoteRepository {
        try GRDBNoteRepository(databaseURL: tempURL)
    }
    private func note(_ content: String, at date: Date = Date()) -> Note {
        Note(id: UUID(), content: content, createdAt: date, updatedAt: nil)
    }

    func test_저장_후_조회() async throws {
        let repo = try makeRepo()
        let n = note("첫 메모 #업무")
        try await repo.save(n)
        let fetched = try await repo.note(id: n.id)
        XCTAssertEqual(fetched, n)
    }

    func test_저장은_upsert() async throws {
        let repo = try makeRepo()
        var n = note("원본")
        try await repo.save(n)
        n.content = "수정본"
        n.updatedAt = Date()
        try await repo.save(n)
        let fetched = try await repo.note(id: n.id)
        XCTAssertEqual(fetched?.content, "수정본")
        let all = try await repo.exportAll()
        XCTAssertEqual(all.count, 1)
    }

    func test_저장_시_태그가_추출되어_저장된다() async throws {
        let repo = try makeRepo()
        try await repo.save(note("#업무 회의 #아이디어"))
        let tags = try await repo.allTags()
        XCTAssertEqual(tags, ["아이디어", "업무"])  // 사전순
    }

    func test_본문_수정_시_태그가_재계산된다() async throws {
        let repo = try makeRepo()
        var n = note("#업무 메모")
        try await repo.save(n)
        n.content = "#개인 메모"
        try await repo.save(n)
        let tags = try await repo.allTags()
        XCTAssertEqual(tags, ["개인"])
    }

    func test_삭제_시_태그도_함께_삭제된다() async throws {
        let repo = try makeRepo()
        let n = note("#업무 메모")
        try await repo.save(n)
        try await repo.delete(id: n.id)
        let fetched = try await repo.note(id: n.id)
        XCTAssertNil(fetched)
        let tags = try await repo.allTags()
        XCTAssertEqual(tags, [])
    }

    func test_같은_경로로_다시_열어도_데이터_유지() async throws {
        let n = note("영속성 확인")
        do {
            let repo = try makeRepo()
            try await repo.save(n)
        }
        let reopened = try GRDBNoteRepository(databaseURL: tempURL)
        let fetched = try await reopened.note(id: n.id)
        XCTAssertEqual(fetched?.content, "영속성 확인")
        XCTAssertNil(fetched?.folderId)
    }

    func test_timeline_before가_nil이면_createdAt_내림차순으로_반환() async throws {
        let repo = try makeRepo()
        let t0 = Date(timeIntervalSince1970: 1_000.123)
        let t1 = Date(timeIntervalSince1970: 2_000.456)
        let t2 = Date(timeIntervalSince1970: 3_000.789)
        try await repo.save(note("n0", at: t0))
        try await repo.save(note("n1", at: t1))
        try await repo.save(note("n2", at: t2))

        let all = try await repo.timeline(filter: .all, before: nil, limit: 10)
        XCTAssertEqual(all.map { $0.content }, ["n2", "n1", "n0"])
    }

    func test_timeline_before_지정시_해당_시각_이후를_제외하고_limit을_적용한다() async throws {
        let repo = try makeRepo()
        let t0 = Date(timeIntervalSince1970: 1_000.123)
        let t1 = Date(timeIntervalSince1970: 2_000.456)
        let t2 = Date(timeIntervalSince1970: 3_000.789)
        try await repo.save(note("n0", at: t0))
        try await repo.save(note("n1", at: t1))
        try await repo.save(note("n2", at: t2))

        // t2 자신을 포함해 t2 이후는 제외되어야 한다 (createdAt < before).
        let beforeT2 = try await repo.timeline(filter: .all, before: t2, limit: 10)
        XCTAssertEqual(beforeT2.map { $0.content }, ["n1", "n0"])

        // limit이 적용되어 최신 2건만 반환되어야 한다.
        let limited = try await repo.timeline(filter: .all, before: nil, limit: 2)
        XCTAssertEqual(limited.map { $0.content }, ["n2", "n1"])
    }
}
