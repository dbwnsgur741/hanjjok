import Foundation

/// [v1.1] 1단계 평면 폴더. 메모의 소속(1개, nullable=미분류)을 나타낸다.
/// 태그(가로 분류, 여러 개 가능)와 역할이 다르며 병행한다.
public struct Folder: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var sortOrder: Int
    public let createdAt: Date

    public init(id: UUID, name: String, sortOrder: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

/// timeline·search에 적용하는 폴더 필터.
public enum FolderFilter: Equatable, Sendable {
    case all
    case unfiled
    case folder(UUID)
}

/// 드로어에 표시할 폴더별·미분류·전체 메모 개수.
public struct FolderCounts: Equatable, Sendable {
    public let all: Int
    public let unfiled: Int
    public let byFolder: [UUID: Int]

    public init(all: Int, unfiled: Int, byFolder: [UUID: Int]) {
        self.all = all
        self.unfiled = unfiled
        self.byFolder = byFolder
    }
}

/// 드로어에 표시할 태그별 메모 개수.
public struct TagCount: Equatable, Sendable {
    public let tag: String
    public let count: Int

    public init(tag: String, count: Int) {
        self.tag = tag
        self.count = count
    }
}
