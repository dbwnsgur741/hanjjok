import XCTest
@testable import Domain

final class MarkdownExporterTests: XCTestCase {
    private func note(_ content: String, _ iso: String) -> Note {
        let f = ISO8601DateFormatter()
        return Note(id: UUID(), content: content, createdAt: f.date(from: iso)!, updatedAt: nil)
    }

    func test_날짜별_그룹과_시각_표기() {
        let notes = [
            note("첫 메모", "2026-08-30T09:30:00+09:00"),
            note("둘째 메모 #업무", "2026-08-30T14:00:00+09:00"),
            note("셋째\n줄바꿈 포함", "2026-08-31T08:00:00+09:00"),
        ]
        let md = MarkdownExporter.export(notes, timeZone: TimeZone(identifier: "Asia/Seoul")!)
        XCTAssertEqual(md, """
        # 한지 전체 내보내기

        ## 2026-08-30

        - **09:30** 첫 메모
        - **14:00** 둘째 메모 #업무

        ## 2026-08-31

        - **08:00** 셋째
          줄바꿈 포함

        """)
    }
    func test_빈_목록() {
        XCTAssertEqual(MarkdownExporter.export([], timeZone: .current), "# 한지 전체 내보내기\n")
    }
}
