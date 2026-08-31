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
                request = NoteRow.filter(Column("created_at") < before)
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
        // Task 6에서 구현. 프로토콜 준수를 위한 임시 스텁.
        []
    }

    public func backup(to url: URL) throws {
        let destination = try DatabaseQueue(path: url.path)
        try pool.backup(to: destination)
    }
}
