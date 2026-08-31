import Foundation
import GRDB
import Domain

struct FolderRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "folder"

    // NoteRow와 동일한 이유로 배정밀도 실수 그대로 왕복한다 (createdAt Equatable 비교 성립 목적).
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .timeIntervalSinceReferenceDate
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .timeIntervalSinceReferenceDate
    }

    var id: String
    var name: String
    var sortOrder: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    init(from folder: Folder) {
        id = folder.id.uuidString
        name = folder.name
        sortOrder = folder.sortOrder
        createdAt = folder.createdAt
    }

    func toFolder() -> Folder? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Folder(id: uuid, name: name, sortOrder: sortOrder, createdAt: createdAt)
    }
}
