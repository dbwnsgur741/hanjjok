import Foundation
import GRDB
import Domain

public final class GRDBNoteRepository: NoteRepository, @unchecked Sendable {
    private let pool: DatabasePool

    public init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        pool = try DatabasePool(path: databaseURL.path)  // DatabasePool은 기본이 WAL 모드
        try Self.migrator.migrate(pool)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
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
        // [v1.1] 1단계 평면 폴더. 폴더 삭제 시 소속 메모는 folder_id가 NULL(미분류)로 전환된다.
        migrator.registerMigration("v2") { db in
            try db.create(table: "folder") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("sort_order", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull()
            }
            try db.alter(table: "note") { t in
                t.add(column: "folder_id", .text)
                    .references("folder", onDelete: .setNull)
                    .indexed()
            }
        }
        return migrator
    }

    public func save(_ note: Note) async throws {
        let row = NoteRow(from: note)
        let tags = HashtagParser.tags(in: note.content)
        try await pool.write { db in
            try row.save(db)
            try db.execute(sql: "DELETE FROM note_tag WHERE note_id = ?", arguments: [row.id])
            for tag in tags {
                try db.execute(
                    sql: "INSERT INTO note_tag (note_id, tag) VALUES (?, ?)",
                    arguments: [row.id, tag])
            }
        }
    }

    public func saveAll(_ notes: [Note]) async throws {
        let rows = notes.map { (NoteRow(from: $0), HashtagParser.tags(in: $0.content)) }
        try await pool.write { db in
            for (row, tags) in rows {
                try row.save(db)
                for tag in tags {
                    try db.execute(
                        sql: "INSERT OR IGNORE INTO note_tag (note_id, tag) VALUES (?, ?)",
                        arguments: [row.id, tag])
                }
            }
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await pool.write { db in
            try NoteRow.deleteOne(db, key: id.uuidString)
        }
    }

    public func note(id: UUID) async throws -> Note? {
        try await pool.read { db in
            try NoteRow.fetchOne(db, key: id.uuidString)?.toNote()
        }
    }

    public func timeline(filter: FolderFilter, before: Date?, limit: Int) async throws -> [Note] {
        try await pool.read { db in
            var conditions: [String] = []
            var args: [DatabaseValueConvertible] = []

            if let folderCondition = Self.folderCondition(filter, args: &args) {
                conditions.append(folderCondition)
            }
            if let before {
                // created_at은 NoteRow의 .timeIntervalSinceReferenceDate 전략으로
                // REAL(배정밀도 실수)로 저장된다. 여기서 Date를 직접 비교하면 기본
                // Date.databaseValue(문자열)로 인코딩되어 REAL < TEXT가 되고,
                // SQLite의 타입 정렬 순서상 REAL은 항상 TEXT보다 작다고 취급되어
                // 필터가 사실상 무시된다. 저장과 동일한 표현(timeIntervalSinceReferenceDate)
                // 으로 명시 변환해 비교해야 한다.
                conditions.append("created_at < ?")
                args.append(before.timeIntervalSinceReferenceDate)
            }

            let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
            let rows = try NoteRow.fetchAll(
                db,
                sql: "SELECT * FROM note \(whereClause) ORDER BY created_at DESC LIMIT \(limit)",
                arguments: StatementArguments(args))
            return rows.compactMap { $0.toNote() }
        }
    }

    /// filter를 SQL 조건 문자열로 변환하며, 필요한 바인딩 인자를 args에 덧붙인다.
    /// .all은 조건 없음(nil), .unfiled는 IS NULL, .folder(id)는 등호 비교.
    private static func folderCondition(_ filter: FolderFilter, args: inout [DatabaseValueConvertible]) -> String? {
        switch filter {
        case .all:
            return nil
        case .unfiled:
            return "folder_id IS NULL"
        case .folder(let id):
            args.append(id.uuidString)
            return "folder_id = ?"
        }
    }

    public func allTags() async throws -> [String] {
        try await pool.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT tag FROM note_tag ORDER BY tag")
        }
    }

    public func exportAll() async throws -> [Note] {
        try await pool.read { db in
            try NoteRow.order(Column("created_at").asc).fetchAll(db).compactMap { $0.toNote() }
        }
    }

    public func search(_ query: SearchQuery, filter: FolderFilter, limit: Int) async throws -> [Note] {
        try await pool.read { db in
            var conditions: [String] = []
            var args: [DatabaseValueConvertible] = []

            if let folderCondition = Self.folderCondition(filter, args: &args) {
                conditions.append(folderCondition)
            }

            switch query.text {
            case .choseong(let q):
                conditions.append("choseong LIKE ? ESCAPE '\\'")
                args.append("%\(Self.escapeLike(q))%")
            case .jamo(let q):
                conditions.append("jamo LIKE ? ESCAPE '\\'")
                args.append("%\(Self.escapeLike(q))%")
            case .plain(let q):
                conditions.append("lower(content) LIKE ? ESCAPE '\\'")
                args.append("%\(Self.escapeLike(q))%")
            case nil:
                break
            }

            if !query.tags.isEmpty {
                let placeholders = Array(repeating: "?", count: query.tags.count).joined(separator: ", ")
                conditions.append("""
                    id IN (SELECT note_id FROM note_tag WHERE tag IN (\(placeholders))
                           GROUP BY note_id HAVING COUNT(DISTINCT tag) = \(query.tags.count))
                    """)
                args.append(contentsOf: query.tags)
            }

            let whereClause = conditions.isEmpty ? "1" : conditions.joined(separator: " AND ")
            let rows = try NoteRow.fetchAll(
                db,
                sql: "SELECT * FROM note WHERE \(whereClause) ORDER BY created_at DESC LIMIT \(limit)",
                arguments: StatementArguments(args))
            return rows.compactMap { $0.toNote() }
        }
    }

    static func escapeLike(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    // MARK: - [v1.1] 폴더

    public func folders() async throws -> [Folder] {
        try await pool.read { db in
            try FolderRow.order(Column("sort_order"), Column("created_at"))
                .fetchAll(db).compactMap { $0.toFolder() }
        }
    }

    public func saveFolder(_ folder: Folder) async throws {
        let row = FolderRow(from: folder)
        try await pool.write { db in
            try row.save(db)
        }
    }

    public func deleteFolder(id: UUID) async throws {
        // note.folder_id는 ON DELETE SET NULL FK로 정의되어 있어, 삭제만으로
        // 소속 메모가 자동으로 미분류(NULL) 처리된다 — 애플리케이션 레벨의 별도 UPDATE 불필요.
        _ = try await pool.write { db in
            try FolderRow.deleteOne(db, key: id.uuidString)
        }
    }

    public func folderCounts() async throws -> FolderCounts {
        try await pool.read { db in
            let all = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM note") ?? 0
            let unfiled = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM note WHERE folder_id IS NULL") ?? 0
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT folder_id, COUNT(*) AS cnt FROM note
                    WHERE folder_id IS NOT NULL GROUP BY folder_id
                    """)
            var byFolder: [UUID: Int] = [:]
            for row in rows {
                let idString: String = row["folder_id"]
                guard let uuid = UUID(uuidString: idString) else { continue }
                byFolder[uuid] = row["cnt"]
            }
            return FolderCounts(all: all, unfiled: unfiled, byFolder: byFolder)
        }
    }

    public func tagCounts() async throws -> [TagCount] {
        try await pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT tag, COUNT(*) AS cnt FROM note_tag GROUP BY tag ORDER BY tag")
            return rows.map { TagCount(tag: $0["tag"], count: $0["cnt"]) }
        }
    }

    public func backup(to url: URL) throws {
        let destination = try DatabaseQueue(path: url.path)
        try pool.backup(to: destination)
    }
}
