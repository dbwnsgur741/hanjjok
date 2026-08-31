import XCTest
@testable import Domain

final class NoteTests: XCTestCase {
    func test_노트_생성과_동등성() {
        let id = UUID()
        let now = Date()
        let a = Note(id: id, content: "첫 메모", createdAt: now, updatedAt: nil)
        let b = Note(id: id, content: "첫 메모", createdAt: now, updatedAt: nil)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.id, id)
    }
}
