import Foundation

public struct Note: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date?
    /// [v1.1] 소속 폴더. nil이면 미분류.
    public var folderId: UUID?

    public init(id: UUID, content: String, createdAt: Date, updatedAt: Date?, folderId: UUID? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderId = folderId
    }
}
