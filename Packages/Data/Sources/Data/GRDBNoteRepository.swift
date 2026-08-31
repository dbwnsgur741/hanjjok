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

    public func timeline(before: Date?, limit: Int) async throws -> [Note] {
        try await pool.read { db in
            var request = NoteRow.order(Column("created_at").desc).limit(limit)
            if let before {
                // created_at은 NoteRow의 .timeIntervalSinceReferenceDate 전략으로
                // REAL(배정밀도 실수)로 저장된다. 여기서 Date를 직접 비교하면 기본
                // Date.databaseValue(문자열)로 인코딩되어 REAL < TEXT가 되고,
                // SQLite의 타입 정렬 순서상 REAL은 항상 TEXT보다 작다고 취급되어
                // 필터가 사실상 무시된다. 저장과 동일한 표현(timeIntervalSinceReferenceDate)
                // 으로 명시 변환해 비교해야 한다.
                request = NoteRow.filter(Column("created_at") < before.timeIntervalSinceReferenceDate)
                    .order(Column("created_at").desc).limit(limit)
            }
            return try request.fetchAll(db).compactMap { $0.toNote() }
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

    public func search(_ query: SearchQuery, limit: Int) async throws -> [Note] {
        try await pool.read { db in
            var conditions: [String] = []
            var args: [DatabaseValueConvertible] = []

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

    public func backup(to url: URL) throws {
        let destination = try DatabaseQueue(path: url.path)
        try pool.backup(to: destination)
    }
}
