import Foundation
import GRDB
import Domain

struct NoteRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "note"

    // GRDB의 기본 Date 인코딩은 밀리초까지만 보존한다 ("yyyy-MM-dd HH:mm:ss.SSS").
    // Note.createdAt/updatedAt은 Date()의 서브밀리초 정밀도를 그대로 왕복해야
    // Equatable 비교가 성립하므로, Date의 내부 저장값과 동일한 배정밀도 실수를
    // 그대로 저장/복원하는 전략을 사용한다 (스키마의 .datetime 컬럼 타입·이름은 불변).
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .timeIntervalSinceReferenceDate
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .timeIntervalSinceReferenceDate
    }

    var id: String
    var content: String
    var createdAt: Date
    var updatedAt: Date?
    var jamo: String
    var choseong: String
    /// [v1.1] 소속 폴더 id. nil이면 미분류. 폴더 삭제 시 FK ON DELETE SET NULL로 자동 전환된다.
    var folderId: String?

    enum CodingKeys: String, CodingKey {
        case id, content, jamo, choseong
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case folderId = "folder_id"
    }

    init(from note: Note) {
        id = note.id.uuidString
        content = note.content
        createdAt = note.createdAt
        updatedAt = note.updatedAt
        jamo = HangulIndexer.jamo(note.content)
        choseong = HangulIndexer.choseong(note.content)
        folderId = note.folderId?.uuidString
    }

    func toNote() -> Note? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Note(id: uuid, content: content, createdAt: createdAt, updatedAt: updatedAt,
                    folderId: folderId.flatMap(UUID.init(uuidString:)))
    }
}
