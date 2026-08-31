import Foundation

public enum HangulIndexer {
    // 유니코드 한글 음절 = 0xAC00 + (초성×21 + 중성)×28 + 종성
    private static let cho: [Character] = [
        "ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ",
        "ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ",
    ]
    private static let jung: [String] = [
        "ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅗㅏ",
        "ㅗㅐ","ㅗㅣ","ㅛ","ㅜ","ㅜㅓ","ㅜㅔ","ㅜㅣ","ㅠ","ㅡ","ㅡㅣ","ㅣ",
    ]
    private static let jong: [String] = [
        "","ㄱ","ㄲ","ㄱㅅ","ㄴ","ㄴㅈ","ㄴㅎ","ㄷ","ㄹ","ㄹㄱ",
        "ㄹㅁ","ㄹㅂ","ㄹㅅ","ㄹㅌ","ㄹㅍ","ㄹㅎ","ㅁ","ㅂ","ㅂㅅ","ㅅ",
        "ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ",
    ]
    /// 단독으로 입력된 겹자모의 분해형 (조합 중 입력·자모 단독 표기 대응)
    private static let compat: [Character: String] = [
        "ㄳ": "ㄱㅅ", "ㄵ": "ㄴㅈ", "ㄶ": "ㄴㅎ", "ㄺ": "ㄹㄱ", "ㄻ": "ㄹㅁ",
        "ㄼ": "ㄹㅂ", "ㄽ": "ㄹㅅ", "ㄾ": "ㄹㅌ", "ㄿ": "ㄹㅍ", "ㅀ": "ㄹㅎ",
        "ㅄ": "ㅂㅅ", "ㅘ": "ㅗㅏ", "ㅙ": "ㅗㅐ", "ㅚ": "ㅗㅣ", "ㅝ": "ㅜㅓ",
        "ㅞ": "ㅜㅔ", "ㅟ": "ㅜㅣ", "ㅢ": "ㅡㅣ",
    ]

    public static func jamo(_ text: String) -> String {
        jamoWithOffsets(text).jamo
    }

    /// jamo 문자열과, 각 jamo 문자가 원문의 몇 번째 Character에서 왔는지의 매핑
    public static func jamoWithOffsets(_ text: String) -> (jamo: String, owner: [Int]) {
        var out = ""
        var owner: [Int] = []
        for (i, ch) in text.enumerated() {
            let piece = decompose(ch)
            out += piece
            owner.append(contentsOf: Array(repeating: i, count: piece.count))
        }
        return (out, owner)
    }

    private static func decompose(_ ch: Character) -> String {
        guard ch.unicodeScalars.count == 1, let scalar = ch.unicodeScalars.first else {
            return String(ch).lowercased()
        }
        let v = scalar.value
        if (0xAC00...0xD7A3).contains(v) {
            let idx = Int(v - 0xAC00)
            return String(cho[idx / (21 * 28)]) + jung[(idx % (21 * 28)) / 28] + jong[idx % 28]
        }
        if let expanded = compat[ch] { return expanded }
        return String(ch).lowercased()
    }

    /// 문자당 정확히 1문자 반환 — 음절은 초성, 그 외는 소문자 첫 문자
    public static func choseongChar(_ ch: Character) -> Character {
        if ch.unicodeScalars.count == 1, let s = ch.unicodeScalars.first,
           (0xAC00...0xD7A3).contains(s.value) {
            return cho[Int(s.value - 0xAC00) / (21 * 28)]
        }
        return String(ch).lowercased().first ?? ch
    }

    public static func choseong(_ text: String) -> String {
        String(text.map(choseongChar))
    }

    /// 공백을 제외한 모든 문자가 호환 자음(U+3131~U+314E)이면 초성 질의
    public static func isChoseongQuery(_ query: String) -> Bool {
        let stripped = query.filter { !$0.isWhitespace }
        guard !stripped.isEmpty else { return false }
        return stripped.allSatisfy { ch in
            guard ch.unicodeScalars.count == 1, let s = ch.unicodeScalars.first else { return false }
            return (0x3131...0x314E).contains(s.value)
        }
    }
}
