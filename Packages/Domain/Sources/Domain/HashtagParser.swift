import Foundation

public enum HashtagParser {
    /// 태그 문자: 한글 음절, 호환 자모(조합 중 입력 포함), 영문, 숫자, 언더스코어
    static let tagPattern = try! NSRegularExpression(pattern: "#([가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9_]+)", options: [])

    /// 본문에서 태그를 추출한다. 등장 순서 유지, 중복 제거, 영문은 소문자 정규화.
    public static func tags(in content: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)

        for match in tagPattern.matches(in: content, options: [], range: range) {
            if let tagRange = Range(match.range(at: 1), in: content) {
                let tag = String(content[tagRange]).lowercased()
                if seen.insert(tag).inserted { result.append(tag) }
            }
        }
        return result
    }
}
