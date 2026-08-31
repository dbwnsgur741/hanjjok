import Foundation

public struct Note: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date?

    public init(id: UUID, content: String, createdAt: Date, updatedAt: Date?) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
