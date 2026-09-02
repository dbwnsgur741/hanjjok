import XCTest
import Domain
@testable import Data

final class BackupSchedulerTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hanjjok-backup-\(UUID().uuidString)")
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }
    private func makeRepo() throws -> GRDBNoteRepository {
        try GRDBNoteRepository(databaseURL: dir.appendingPathComponent("db/hanjjok.sqlite"))
    }
    private var backupsDir: URL { dir.appendingPathComponent("Backups") }
    private func day(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.date(from: s)!
    }
    private func backupNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: backupsDir.path)
            .filter { $0.hasSuffix(".sqlite") }.sorted()
    }

    func test_첫_실행은_백업을_만든다() async throws {
        let repo = try makeRepo()
        try await repo.save(Note(id: UUID(), content: "백업 대상", createdAt: Date(), updatedAt: nil))
        let ran = try BackupScheduler.runIfNeeded(repository: repo, backupsDir: backupsDir, now: day("2026-08-31"))
        XCTAssertTrue(ran)
        XCTAssertEqual(try backupNames(), ["hanjjok-2026-08-31.sqlite"])
    }

    func test_같은_날_두_번째_실행은_건너뛴다() async throws {
        let repo = try makeRepo()
        _ = try BackupScheduler.runIfNeeded(repository: repo, backupsDir: backupsDir, now: day("2026-08-31"))
        let ran = try BackupScheduler.runIfNeeded(repository: repo, backupsDir: backupsDir, now: day("2026-08-31"))
        XCTAssertFalse(ran)
        XCTAssertEqual(try backupNames().count, 1)
    }

    func test_7개_초과분은_오래된_것부터_삭제() async throws {
        let repo = try makeRepo()
        for d in 1...9 {
            _ = try BackupScheduler.runIfNeeded(
                repository: repo, backupsDir: backupsDir,
                now: day(String(format: "2026-08-%02d", d)))
        }
        let names = try backupNames()
        XCTAssertEqual(names.count, 7)
        XCTAssertEqual(names.first, "hanjjok-2026-08-03.sqlite")
        XCTAssertEqual(names.last, "hanjjok-2026-08-09.sqlite")
    }

    func test_백업_파일은_열어서_읽을_수_있다() async throws {
        let repo = try makeRepo()
        let n = Note(id: UUID(), content: "복구 확인", createdAt: Date(), updatedAt: nil)
        try await repo.save(n)
        _ = try BackupScheduler.runIfNeeded(repository: repo, backupsDir: backupsDir, now: day("2026-08-31"))
        let restored = try GRDBNoteRepository(
            databaseURL: backupsDir.appendingPathComponent("hanjjok-2026-08-31.sqlite"))
        let fetched = try await restored.note(id: n.id)
        XCTAssertEqual(fetched?.content, "복구 확인")
    }
}
