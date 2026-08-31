import Foundation

public enum HashtagParser {
    /// 태그 문자: 한글 음절, 호환 자모(조합 중 입력 포함), 영문, 숫자, 언더스코어
    public static let tagPattern = #/#([가-힣ㄱ-ㅎㅏ-ㅣA-Za-z0-9_]+)/#

    /// 본문에서 태그를 추출한다. 등장 순서 유지, 중복 제거, 영문은 소문자 정규화.
    public static func tags(in content: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for match in content.matches(of: tagPattern) {
            let tag = String(match.1).lowercased()
            if seen.insert(tag).inserted { result.append(tag) }
        }
        return result
    }
}
