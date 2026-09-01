import Foundation

/// 전체 내보내기 — 마크다운 변환. `notes`는 createdAt 오름차순 입력을 전제한다
/// (Data.exportAll()이 이미 오름차순으로 반환).
public enum MarkdownExporter {
    public static func export(_ notes: [Note], timeZone: TimeZone = .current) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = timeZone
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = timeZone
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        var out = "# 갈피 전체 내보내기\n"
        var currentDay = ""
        for note in notes {
            let day = dayFormatter.string(from: note.createdAt)
            if day != currentDay {
                out += "\n## \(day)\n\n"
                currentDay = day
            }
            let body = note.content.replacingOccurrences(of: "\n", with: "\n  ")
            out += "- **\(timeFormatter.string(from: note.createdAt))** \(body)\n"
        }
        return out
    }
}
