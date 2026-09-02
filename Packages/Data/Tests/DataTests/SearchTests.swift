import XCTest
import Domain
@testable import Data

final class SearchTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hanjjok-search-\(UUID().uuidString)")
            .appendingPathComponent("test.sqlite")
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }
    private func makeRepo() throws -> GRDBNoteRepository {
        try GRDBNoteRepository(databaseURL: tempURL)
    }
    private func seed(_ repo: GRDBNoteRepository) async throws {
        let base = Date(timeIntervalSince1970: 1_756_600_000)
        let contents = ["사이드노트 조사", "회의 정리 #업무", "Memo backup 확인", "노을 사진 찍기", "왜냐하면 그렇다"]
        for (i, c) in contents.enumerated() {
            try await repo.save(Note(id: UUID(), content: c,
                                     createdAt: base.addingTimeInterval(Double(i)), updatedAt: nil))
        }
    }

    func test_초성_검색() async throws {
        let repo = try makeRepo(); try await seed(repo)
        let hits = try await repo.search(.parse("ㅅㅇㄷ"), filter: .all, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["사이드노트 조사"])
    }
    func test_자모_검색_조합_중_입력() async throws {
        let repo = try makeRepo(); try await seed(repo)
        let hits = try await repo.search(.parse("사이ㄷ"), filter: .all, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["사이드노트 조사"])
    }
    func test_영문_대소문자_무시() async throws {
        let repo = try makeRepo(); try await seed(repo)
        let hits = try await repo.search(.parse("MEMO"), filter: .all, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["Memo backup 확인"])
    }
    func test_태그_필터와_텍스트_AND_결합() async throws {
        let repo = try makeRepo(); try await seed(repo)
        let hits = try await repo.search(.parse("#업무 회의"), filter: .all, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["회의 정리 #업무"])
        let miss = try await repo.search(.parse("#업무 사이드"), filter: .all, limit: 10)
        XCTAssertEqual(miss, [])
    }
    func test_LIKE_특수문자는_이스케이프() async throws {
        let repo = try makeRepo()
        try await repo.save(Note(id: UUID(), content: "진행률 100% 달성",
                                 createdAt: Date(), updatedAt: nil))
        let hits = try await repo.search(.parse("100%"), filter: .all, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["진행률 100% 달성"])
        let miss = try await repo.search(.parse("1%0"), filter: .all, limit: 10)  // %가 와일드카드로 동작하면 매치돼버림
        XCTAssertEqual(miss, [])
    }
    func test_결과는_최신순() async throws {
        let repo = try makeRepo(); try await seed(repo)
        let base = Date(timeIntervalSince1970: 1_756_700_000)
        try await repo.save(Note(id: UUID(), content: "사이드노트 두 번째",
                                 createdAt: base, updatedAt: nil))
        let hits = try await repo.search(.parse("사이드"), filter: .all, limit: 10)
        XCTAssertEqual(hits.map(\.content), ["사이드노트 두 번째", "사이드노트 조사"])
    }

    func test_1만건_초성_검색_성능() async throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 1_756_000_000)
        let fillers = ["회의 정리", "점심 약속", "코드 리뷰", "배포 준비", "운동 기록"]
        var notes: [Note] = (0..<9_999).map { i in
            Note(id: UUID(), content: "\(fillers[i % fillers.count]) \(i)",
                 createdAt: base.addingTimeInterval(Double(i)), updatedAt: nil)
        }
        notes.append(Note(id: UUID(), content: "사이드노트 프로젝트 한지",
                          createdAt: base.addingTimeInterval(10_000), updatedAt: nil))
        try await repo.saveAll(notes)

        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            let hits = try await repo.search(.parse("ㅅㅇㄷㄴㅌ"), filter: .all, limit: 100)
            XCTAssertEqual(hits.count, 1)
        }
        XCTAssertLessThan(elapsed, .milliseconds(500), "1만 건 초성 검색이 500ms를 넘음: \(elapsed)")
    }
}
