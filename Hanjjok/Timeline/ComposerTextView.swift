import SwiftUI
import AppKit
import Domain

/// 한글 IME 안전 컴포저.
/// `TextEditor.onKeyPress`는 한글 조합 중 Enter에서 마지막 글자를 잃을 수 있다.
/// NSTextView의 `doCommandBy` 인터셉트는 조합 확정 후 호출되므로 IME에 안전하다 — 반드시 이 방식.
struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var onSubmit: () -> Void
    /// [Task 18] 한 줄 입력 모드(폴더명 생성·이름변경 등) — 여백을 좁히고, Shift+Enter도
    /// 줄바꿈 없이 제출로 처리한다(이름 필드는 줄바꿈이 필요 없음). 기본값 false는 기존
    /// 다중행 컴포저(메모 작성·인라인 수정) 동작을 그대로 유지한다.
    var singleLine: Bool = false
    /// [v1.5] 일반 줄에서 Enter가 제출인가(컴포저: 카톡식 보내기) 줄바꿈인가(카드 인라인 수정:
    /// 에디터식, 사용자 결정). false면 저장은 ⌘Enter(HanjjokTextView.onCommandReturn)·푸터
    /// 버튼·포커스 아웃뿐이고, 빈 리스트 마커에서 Enter는 제출 대신 마커만 지운다.
    /// 리스트 연속(ⓐ)·Shift+Enter 줄바꿈(ⓓ)은 양쪽 공통. singleLine이면 이 값과 무관하게 제출.
    var enterSubmits: Bool = true
    /// [v1.5] 생성 직후 first responder가 되어 캐럿을 끝에 둔다(카드 인라인 수정용). 기본 false —
    /// 컴포저·드로어 이름 필드는 기존 포커스 경로를 그대로 쓴다.
    var autoFocus: Bool = false
    /// [Task 24] 메인 컴포저의 체크리스트 삽입 버튼이 NSTextView를 직접 조작할 때 쓰는 브릿지.
    /// 기본값 nil이라 카드 인라인 수정(NoteCardView)·드로어 이름 필드(DrawerView)의 기존
    /// 호출부는 이 인자를 몰라도 소스 호환된다.
    var commands: ComposerCommands? = nil
    /// [QA r3 ③] 이 필드가 포커스를 잃을 때(Coordinator.textDidEndEditing) 호출된다.
    /// NoteCardView 인라인 수정이 여기 연결해 "수정 후 다른 곳 클릭 시 커밋 안 됨" 버그를
    /// 고친다. 기본값 nil이라 메인 컴포저·드로어 이름 필드는 이 인자를 몰라도 소스 호환된다.
    var onFocusLost: (() -> Void)? = nil
    /// [QA r3 ②] 내용 높이가 바뀔 때마다 보고한다(값은 textContainer의 usedRect 높이 +
    /// 위아래 인셋). 호출부가 이 값으로 `.frame(height:)`를 갱신하면 고정 높이 필드가
    /// 내용만큼 자란다. 기본값 nil이라 드로어 한 줄 필드 등 자동 성장이 필요 없는 호출부는
    /// 이 인자를 몰라도 소스 호환된다.
    var onHeightChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // [v1.5] ⌘Enter·⌘B를 스스로 처리하는 서브클래스(파일 하단). scrollableTextView()는
        // 호출한 클래스로 documentView를 만든다(실측 확인).
        let scroll = HanjjokTextView.scrollableTextView()
        let textView = scroll.documentView as! HanjjokTextView
        textView.delegate = context.coordinator
        // ⌘Enter = 제출/저장(컴포저·수정 공통). 조합 중 글자는 서브클래스가 먼저 확정하므로
        // 여기서는 확정된 문자열을 바인딩에 밀어 넣은 뒤 onSubmit을 부른다 — textDidChange는
        // unmarkText만으로는 오지 않을 수 있어 직접 동기화한다(finalizeAndReadText와 같은 이유).
        textView.onCommandReturn = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.parent.text = textView.string
            coordinator.parent.onSubmit()
        }
        textView.font = font
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = singleLine
            ? NSSize(width: 6, height: 3)
            : NSSize(width: 12, height: 10)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        commands?.textView = textView
        // [QA r5-C 실제 원인] macOS 자동 치환이 --- 를 — 로, " 를 " 로 조용히 바꿔 사용자가
        // 친 마크다운을 깨뜨린다(컨트롤러 진단) — singleLine(이름 필드)에 걸어도 무해하므로
        // 조건 없이 전부 끈다.
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        // [QA r5-C Fix round 1] 라이브 문법 강조는 다중행 컴포저에만 배선한다 —
        // singleLine(드로어 이름 필드 등)에 배선하면 폴더명으로 "- 아이디어"나 "# Ideas"를
        // 쳤을 때 그 일부가 흐려 보인다(리뷰 지적, 스펙 위반: singleLine은 강조 대상이
        // 아님). delegate 자체를 안 달아 didProcessEditing이 아예 호출되지 않게 한다.
        if !singleLine {
            textView.textStorage?.delegate = context.coordinator
            context.coordinator.textView = textView
        }
        if autoFocus {
            // 창에 붙은 다음 틱에 — makeNSView 시점엔 아직 window가 nil이다.
            DispatchQueue.main.async { [weak textView] in
                guard let textView, let window = textView.window else { return }
                window.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            }
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        // 스테일 클로저 방지(표준 관례) — SwiftUI가 새 ComposerTextView 값으로 이 메서드를
        // 부르는 시점에 Coordinator가 들고 있던 이전 parent(옛 onSubmit/onFocusLost 등
        // 클로저)를 최신 것으로 갱신한다.
        context.coordinator.parent = self
        let textView = scroll.documentView as! NSTextView
        if textView.string != text {
            // [QA r3 ⑤] 조합 중(marked) 텍스트가 남아 있는 상태로 string을 통째로 교체하면
            // IME 조합 버퍼가 불안정해져 잔여 텍스트가 생긴다 — 대입 전 항상 확정한다.
            if textView.hasMarkedText() { textView.unmarkText() }
            textView.string = text
        }
        // [QA r5-C Fix round 1] font를 무조건 재대입하면 안 된다 — isRichText가 false라
        // NSTextView.font 세터는 문서 전체를 그 폰트 하나로 통일된 속성으로 다시 씌운다
        // (리뷰 실증: addAttribute로 얹은 굵게가 같은 값을 재대입해도 사라짐). updateNSView는
        // 키 입력마다(textDidChange → binding → SwiftUI 재렌더) 불리므로 무조건 대입하면
        // 라이브 강조(제목 크기·굵게·기울임·코드)가 매 키 입력마다 통째로 지워진다 —
        // 실제로 값이 바뀔 때만 대입한다. 본문 폰트 설정을 MaruBuri↔Pretendard로 토글할
        // 때는 font가 실제로 달라지므로 이 분기가 정상적으로 실행돼 문서 전체가 새
        // 폰트로 리셋된다(의도된 동작).
        if textView.font != font {
            textView.font = font
        }
        // 새로 입력될 글자가 강조 재적용 전까지 기본 폰트로 시작하도록 typingAttributes도
        // 맞춰 둔다.
        textView.typingAttributes[.font] = font
        context.coordinator.reportHeight(from: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: ComposerTextView
        /// [QA r3 ②] 직전에 보고한 높이 — 0.5pt 미만 변화는 다시 보고하지 않아 SwiftUI 쪽
        /// height binding ↔ NSTextView 레이아웃 사이의 무한 갱신 루프를 막는다.
        private var lastReportedHeight: CGFloat?
        /// [QA r5-C] 라이브 강조가 hasMarkedText()·effectiveAppearance(다크모드 판정)를
        /// 읽을 때 쓰는 약한 참조 — makeNSView가 채운다.
        weak var textView: NSTextView?
        init(_ parent: ComposerTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            reportHeight(from: tv)
        }

        /// [QA r3 ③] 포커스 아웃 — 인라인 수정 필드가 이걸 통해 커밋을 트리거한다.
        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusLost?()
        }

        /// [QA r5-C] 라이브 마크다운 강조. 이 태스크 최대 위험은 한글 조합(IME) 도중
        /// 속성을 얹어 조합을 깨뜨리는 것이므로, hasMarkedText() 가드를 최우선으로 둔다.
        /// `.editedCharacters` 마스크만 통과시키는 것도 안전장치다 — 이 함수 안에서 하는
        /// attribute 전용 변경(addAttribute 등)이 스스로를 다시 부르더라도 그 재진입
        /// 호출의 마스크에는 `.editedCharacters`가 없으므로 여기서 즉시 빠져나가
        /// 무한 재귀가 생기지 않는다.
        func textStorage(_ textStorage: NSTextStorage,
                          didProcessEditing editedMask: NSTextStorageEditActions,
                          range editedRange: NSRange,
                          changeInLength delta: Int) {
            // [QA r5-C Fix round 1] singleLine(드로어 이름 필드 등)은 강조 대상이 아니다 —
            // makeNSView가 이미 이 경우 delegate 자체를 안 달지만, 방어적으로 한 번 더
            // 막는다(스펙 위반 재발 방지).
            guard !parent.singleLine else { return }
            guard editedMask.contains(.editedCharacters) else { return }
            guard let tv = textView, !tv.hasMarkedText() else { return }
            let isDark = tv.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ComposerSyntaxHighlighter.apply(to: textStorage, baseFont: parent.font, isDark: isDark)
        }

        /// [QA r3 ②] 내용 높이를 계산해 직전 보고값과 0.5pt 이상 차이날 때만 콜백한다.
        /// `DispatchQueue.main.async`로 넘기는 이유: 이 메서드가 SwiftUI의 뷰 업데이트
        /// 사이클 도중(updateNSView 끝)에도 불리는데, 그 안에서 바로 @State를 바꾸면
        /// "Modifying state during view update" 경고가 뜬다.
        func reportHeight(from textView: NSTextView) {
            guard let onHeightChange = parent.onHeightChange,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            layoutManager.ensureLayout(for: textContainer)
            let used = layoutManager.usedRect(for: textContainer)
            let height = used.height + textView.textContainerInset.height * 2
            if lastReportedHeight == nil || abs(height - lastReportedHeight!) > 0.5 {
                lastReportedHeight = height
                DispatchQueue.main.async { onHeightChange(height) }
            }
        }

        /// [QA r4] MD 에디터식 Enter 의미론(스펙 §8 ⑦ 확정) — r2의 "Shift+Enter 연속" 규칙을
        /// 대체한다. singleLine(드로어 이름 필드)은 예전처럼 Enter가 곧 제출이다. 다중행
        /// 모드는 Shift+Enter가 항상 일반 줄바꿈(ⓓ, 항목 뒤에 평문을 넣는 통로)이고, 캐럿이
        /// 있는 줄이 체크리스트·불릿·인용 항목이면 Enter가 본문 유무로 갈린다: 본문 있으면
        /// 다음 줄에 새 마커를 이어 붙여 연속 입력(ⓐ, 제출 아님), 본문 없으면(항목을
        /// 끝내려는 신호) 그 빈 마커 줄을 지우고 제출한다(ⓑ). 세 종류 다 아니면 예전처럼
        /// Enter = 제출(ⓒ, 카톡식 유지).
        /// [QA r5-C] 판정은 `Domain.MarkdownParser.blocks(in:)`의 첫 블록으로 한다(정규식
        /// 중복 금지) — 체크리스트뿐이던 연속을 불릿·인용까지 확장하면서도 새 정규식을
        /// 만들지 않는다. 단 MarkdownParser.bulletRegex는 본문 없는 "- "/"* "를 의도적으로
        /// 문단으로 분류한다(그 종료 판정은 이 태스크가 대신 내리라는 주석이 MarkdownParser.swift에
        /// 있음) — 그 경우만 별도로 확인한다.
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                if parent.singleLine { parent.onSubmit(); return true }
                // ⓓ Shift+Enter = 항상 일반 줄바꿈 — 항목 뒤에 일반 텍스트를 넣는 통로.
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { return false }
                let ns = textView.string as NSString
                let caretRange = textView.selectedRange()
                let lineRange = ns.lineRange(for: caretRange)
                let currentLine = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
                let submits = parent.enterSubmits

                // ⓑ 빈 항목에서 Enter = 리스트 종료. 컴포저(enterSubmits)는 마커 줄을 지우고
                // 제출하고, 수정 모드는 마커만 지워 그 줄에 캐럿을 남긴다(제출 아님). insertText가
                // textDidChange를 동기 발화해 바인딩이 갱신된 뒤 — 그 순서 그대로 — onSubmit이
                // 실행돼야 한다(순서 뒤집으면 옛 마커 줄이 저장됨).
                func endItem() -> Bool {
                    if submits {
                        textView.insertText("", replacementRange: lineRange)
                        parent.onSubmit()
                    } else {
                        var markerRange = lineRange
                        if ns.substring(with: lineRange).hasSuffix("\n") { markerRange.length -= 1 }
                        textView.insertText("", replacementRange: markerRange)
                    }
                    return true
                }
                // ⓒ 일반 줄에서 Enter — 컴포저는 제출(카톡식 유지), 수정 모드는 줄바꿈(v1.5, 에디터식).
                func plainEnter() -> Bool {
                    guard submits else { return false }
                    parent.onSubmit()
                    return true
                }

                guard let block = MarkdownParser.blocks(in: currentLine).first else { return plainEnter() }
                switch block {
                case .checklist(let item):
                    if item.text.isEmpty { return endItem() }
                    // ⓐ 본문 있는 항목에서 Enter = 다음 항목 자동 연속(전송 아님).
                    textView.insertText("\n- [ ] ", replacementRange: caretRange)
                    return true
                case .bullet:
                    // 불릿은 본문이 비면 MarkdownParser가 애초에 .bullet으로 분류하지 않으므로
                    // (아래 default에서 처리) 여기서는 항상 계속 입력 케이스만 온다.
                    textView.insertText("\n- ", replacementRange: caretRange)
                    return true
                case .quote(let text, _):
                    if text.isEmpty { return endItem() }
                    textView.insertText("\n> ", replacementRange: caretRange)
                    return true
                default:
                    // MarkdownParser.bulletRegex는 본문 없는 "- "/"* "를 의도적으로 문단으로
                    // 분류한다 — 그 종료 신호만 여기서 직접 잡는다.
                    if currentLine == "- " || currentLine == "* " { return endItem() }
                    return plainEnter()
                }
            }
            return false
        }
    }
}

/// [Task 24] 컴포저 체크리스트 버튼 → NSTextView 브릿지. ComposerTextView.makeNSView가
/// 생성 시 `textView`를 채워주면, SwiftUI 쪽 버튼 액션이 이 클래스를 통해 NSTextView에
/// 직접 마커를 삽입한다(SwiftUI에는 NSTextView의 selectedRange 등을 직접 만질 방법이 없음).
@MainActor
final class ComposerCommands {
    weak var textView: NSTextView?

    /// 캐럿이 있는 줄의 시작 위치에 체크리스트 마커를 삽입한다. [QA r5-C] 표준 마크다운
    /// 문법인 `"- [ ] "`로 통일했다(예전 `"[] "`는 ChecklistParser는 인식해도 일반
    /// 마크다운 뷰어와 호환되지 않았다) — ChecklistParser.lineRegex가 `- ` 접두를
    /// 선택적으로 허용하므로 여전히 새 항목으로 인식된다.
    func insertChecklistMarker() {
        guard let textView else { return }
        let ns = textView.string as NSString
        let lineStart = ns.lineRange(for: textView.selectedRange()).location
        textView.insertText("- [ ] ", replacementRange: NSRange(location: lineStart, length: 0))
        restoreFocus()
    }

    /// [QA r5-C] 현재 줄 접두 토글 — 이미 같은 접두면 벗기고, 다른 리스트류 접두가 있으면
    /// 그것부터 벗긴 뒤 요청 접두로 바꾼다. prefix 예: `"# "`, `"## "`, `"- "`, `"> "`,
    /// `"- [ ] "`. 판정 순서는 긴 것부터 — `"- [ ] "`가 `"- "`보다 먼저 매치돼야 체크리스트
    /// 줄에서 `"- "`만 벗기고 `"[ ] "`를 남기는 사고가 나지 않는다.
    func togglePrefix(_ prefix: String) {
        guard let textView else { return }
        let ns = textView.string as NSString
        let lineRange = ns.lineRange(for: textView.selectedRange())
        var body = ns.substring(with: lineRange)
        // [QA r5-C Fix round 1] 체크된 항목("- [x] "/"- [X] ")도 "- "보다 먼저 매치돼야
        // 한다 — 빠뜨리면 이미 체크된 줄에서 체크리스트 버튼을 눌렀을 때 "- "만 벗겨져
        // "- [ ] [x] Task"처럼 마커가 중첩되는 사고가 난다.
        let knownPrefixes = ["- [ ] ", "- [x] ", "- [X] ", "### ", "## ", "# ", "- ", "> "]
        var existing: String?
        for candidate in knownPrefixes where body.hasPrefix(candidate) {
            existing = candidate
            body.removeFirst(candidate.count)
            break
        }
        let newLine = existing == prefix ? body : prefix + body
        textView.insertText(newLine, replacementRange: lineRange)
        restoreFocus()
    }

    /// [QA r5-C] 선택 영역을 marker로 감싼다(`"**"`·`"*"`·`` "`" ``·`"~~"`). 선택이 없으면
    /// 마커 쌍만 삽입하고 캐럿을 그 사이로 옮긴다. 선택 양옆이 이미 정확히 그 marker면
    /// 벗긴다(토글).
    func wrapSelection(with marker: String) {
        guard let textView else { return }
        Self.wrapSelection(in: textView, with: marker)
        restoreFocus()
    }

    /// [v1.5] 감싸기 본체 — 인스턴스 없이도 쓰도록 분리. HanjjokTextView가 ⌘B를 직접 처리할 때
    /// 이걸 부른다(툴바 버튼과 같은 규칙, 로직 중복 없음).
    static func wrapSelection(in textView: NSTextView, with marker: String) {
        let ns = textView.string as NSString
        let selRange = textView.selectedRange()
        let markerLen = (marker as NSString).length

        let hasLeadingMarker = selRange.location >= markerLen
            && ns.substring(with: NSRange(location: selRange.location - markerLen, length: markerLen)) == marker
        let hasTrailingMarker = selRange.location + selRange.length + markerLen <= ns.length
            && ns.substring(with: NSRange(location: selRange.location + selRange.length, length: markerLen)) == marker

        if hasLeadingMarker && hasTrailingMarker {
            let outerRange = NSRange(location: selRange.location - markerLen,
                                      length: selRange.length + markerLen * 2)
            let inner = ns.substring(with: selRange)
            textView.insertText(inner, replacementRange: outerRange)
            textView.setSelectedRange(NSRange(location: outerRange.location, length: (inner as NSString).length))
        } else {
            let selected = ns.substring(with: selRange)
            textView.insertText(marker + selected + marker, replacementRange: selRange)
            textView.setSelectedRange(NSRange(location: selRange.location + markerLen,
                                               length: (selected as NSString).length))
        }
    }

    /// [QA r5-C] 캐럿 줄 아래에 구분선(`"---"`) 줄을 넣는다 — 현재 줄이 개행으로 끝나지
    /// 않으면(문서 마지막 줄) 개행을 먼저 붙여 구분선이 그 줄과 합쳐지지 않게 하고, 구분선
    /// 뒤에도 개행을 붙여 다음 입력이 구분선과 한 줄로 이어지지 않게 한다.
    func insertDivider() {
        guard let textView else { return }
        let ns = textView.string as NSString
        let lineRange = ns.lineRange(for: textView.selectedRange())
        let lineEnd = lineRange.location + lineRange.length
        let currentLine = ns.substring(with: lineRange)
        let insertion = currentLine.hasSuffix("\n") ? "---\n" : "\n---\n"
        textView.insertText(insertion, replacementRange: NSRange(location: lineEnd, length: 0))
        restoreFocus()
    }

    /// 조합 중(marked) 텍스트를 확정하고 확정된 전체 문자열을 돌려준다.
    /// 보내기 버튼처럼 포커스를 뺏지 않는 경로는 전송 전 반드시 이걸 거쳐야
    /// 조합 중 글자 유실·잔여 텍스트가 없다 (QA r3 ⑤).
    func finalizeAndReadText() -> String? {
        guard let textView else { return nil }
        if textView.hasMarkedText() { textView.unmarkText() }
        return textView.string
    }

    /// [QA r4 ①] 전송 성공 직후 NSTextView를 소스에서 직접 비운다 — SwiftUI의
    /// updateNSView diff 경로에만 의존하면 잔존 텍스트가 재발했다(사용자 2회 보고).
    func clearText() {
        guard let textView else { return }
        if textView.hasMarkedText() { textView.unmarkText() }
        textView.string = ""
    }

    /// [QA r5-C] 툴바 버튼 클릭은 NSButton이 first responder가 되어 텍스트뷰가 포커스를
    /// 잃는다 — 각 명령 끝에 포커스를 텍스트뷰로 되돌려 다음 입력이 바로 이어지게 한다.
    private func restoreFocus() {
        guard let textView else { return }
        NSApp.keyWindow?.makeFirstResponder(textView)
    }
}

/// [QA r5-C] 컴포저 라이브 문법 강조 — 저장되는 텍스트는 절대 건드리지 않고(마커 글자도
/// 지우지 않음) 속성만 얹는다. 블록 판정(제목·구분선·체크리스트·불릿·인용)은
/// `Domain.MarkdownParser.blocks(in:)`을 줄 단위로 재사용해 정규식을 중복시키지 않는다 —
/// MarkdownParser는 인라인 서식을 다루지 않으므로(MarkdownBody.swift 주석 참조)
/// `**굵게**` 등은 여기서 직접 찾는다. 호출부(Coordinator.textStorage(_:didProcessEditing:...))
/// 가 hasMarkedText() 가드와 `.editedCharacters` 마스크 체크를 이미 마쳤다고 가정한다 —
/// 이 타입 자체는 그 가드를 모른다(재사용 시 반드시 호출부에서 가드할 것).
private enum ComposerSyntaxHighlighter {
    private static let boldRegex = try! NSRegularExpression(pattern: #"\*\*([^\n]+?)\*\*"#)
    private static let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#)
    private static let codeRegex = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#)
    private static let strikeRegex = try! NSRegularExpression(pattern: #"~~([^\n]+?)~~"#)

    static func apply(to textStorage: NSTextStorage, baseFont: NSFont, isDark: Bool) {
        let ink = NSColor(isDark ? HanjjokTheme.inkDark : HanjjokTheme.inkLight)
        let full = NSRange(location: 0, length: textStorage.length)
        // 전체를 기본값으로 되돌린 뒤 필요한 구간에만 addAttribute — beginEditing/endEditing
        // 으로 감싸지 않는다(didProcessEditing 안에서는 금지, QA r5-C 브리프).
        textStorage.setAttributes([.font: baseFont, .foregroundColor: ink], range: full)
        guard full.length > 0 else { return }

        let markerColor = ink.withAlphaComponent(0.4)
        let ns = textStorage.string as NSString
        ns.enumerateSubstrings(in: full, options: .byLines) { substring, lineRange, _, _ in
            guard let lineText = substring, !lineText.isEmpty else { return }
            styleBlock(lineText: lineText, lineRange: lineRange, storage: textStorage,
                       baseFont: baseFont, markerColor: markerColor)
            styleInlineAll(lineText: lineText, lineOffset: lineRange.location, storage: textStorage,
                            baseFont: baseFont, markerColor: markerColor)
        }
    }

    // MARK: - 블록 규칙 (MarkdownParser 재사용)

    private static func styleBlock(lineText: String, lineRange: NSRange, storage: NSTextStorage,
                                    baseFont: NSFont, markerColor: NSColor) {
        guard let block = MarkdownParser.blocks(in: lineText).first else { return }
        switch block {
        case .heading(let level, let text, _):
            let size: CGFloat = level == 1 ? 20 : (level == 2 ? 17.5 : 15.5)
            let bold = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            let sizedBold = NSFont(descriptor: bold.fontDescriptor, size: size) ?? bold
            let prefixLength = (lineText as NSString).length - (text as NSString).length
            let bodyRange = NSRange(location: lineRange.location + prefixLength,
                                     length: (text as NSString).length)
            if bodyRange.length > 0 { storage.addAttribute(.font, value: sizedBold, range: bodyRange) }
            markPrefix(length: prefixLength, lineRange: lineRange, storage: storage, markerColor: markerColor)
        case .divider:
            storage.addAttribute(.foregroundColor, value: markerColor, range: lineRange)
        case .checklist(let item):
            markPrefix(bodyText: item.text, lineText: lineText, lineRange: lineRange,
                       storage: storage, markerColor: markerColor)
        case .bullet(let text, _):
            markPrefix(bodyText: text, lineText: lineText, lineRange: lineRange,
                       storage: storage, markerColor: markerColor)
        case .quote(let text, _):
            markPrefix(bodyText: text, lineText: lineText, lineRange: lineRange,
                       storage: storage, markerColor: markerColor)
        case .paragraph:
            break
        }
    }

    /// 줄 접두(마커) 부분만 40% 알파로 — `text`가 항상 `lineText`의 접미(suffix)라는
    /// ChecklistParser/MarkdownParser 정규식의 보장(`.*$`로 끝까지 캡처)을 이용해 길이
    /// 차감만으로 접두 길이를 구한다(별도 정규식 불필요).
    private static func markPrefix(bodyText: String, lineText: String, lineRange: NSRange,
                                    storage: NSTextStorage, markerColor: NSColor) {
        let prefixLength = (lineText as NSString).length - (bodyText as NSString).length
        markPrefix(length: prefixLength, lineRange: lineRange, storage: storage, markerColor: markerColor)
    }

    private static func markPrefix(length: Int, lineRange: NSRange, storage: NSTextStorage, markerColor: NSColor) {
        guard length > 0 else { return }
        storage.addAttribute(.foregroundColor, value: markerColor,
                              range: NSRange(location: lineRange.location, length: length))
    }

    // MARK: - 인라인 규칙 (여기서만 정규식을 새로 씀 — MarkdownParser는 인라인을 다루지 않음)

    private static func styleInlineAll(lineText: String, lineOffset: Int, storage: NSTextStorage,
                                        baseFont: NSFont, markerColor: NSColor) {
        styleInline(boldRegex, lineText: lineText, lineOffset: lineOffset, storage: storage, markerColor: markerColor) { range in
            applyTrait(.boldFontMask, range: range, storage: storage, baseFont: baseFont)
        }
        styleInline(italicRegex, lineText: lineText, lineOffset: lineOffset, storage: storage, markerColor: markerColor) { range in
            applyTrait(.italicFontMask, range: range, storage: storage, baseFont: baseFont)
        }
        styleInline(codeRegex, lineText: lineText, lineOffset: lineOffset, storage: storage, markerColor: markerColor) { range in
            let current = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont) ?? baseFont
            storage.addAttribute(.font,
                                  value: NSFont.monospacedSystemFont(ofSize: current.pointSize, weight: .regular),
                                  range: range)
        }
        styleInline(strikeRegex, lineText: lineText, lineOffset: lineOffset, storage: storage, markerColor: markerColor) { range in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }

    /// marker(regex 그룹 1 밖) 구간은 40% 알파로, 내용(그룹 1) 구간은 styleContent로 스타일한다.
    private static func styleInline(_ regex: NSRegularExpression, lineText: String, lineOffset: Int,
                                     storage: NSTextStorage, markerColor: NSColor,
                                     styleContent: (NSRange) -> Void) {
        let ns = lineText as NSString
        let matches = regex.matches(in: lineText, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let full = match.range(at: 0)
            let inner = match.range(at: 1)
            guard full.location != NSNotFound, inner.location != NSNotFound else { continue }
            let leadingMarker = NSRange(location: lineOffset + full.location, length: inner.location - full.location)
            let trailingStart = inner.location + inner.length
            let trailingMarker = NSRange(location: lineOffset + trailingStart,
                                          length: full.location + full.length - trailingStart)
            if leadingMarker.length > 0 { storage.addAttribute(.foregroundColor, value: markerColor, range: leadingMarker) }
            if trailingMarker.length > 0 { storage.addAttribute(.foregroundColor, value: markerColor, range: trailingMarker) }
            let contentRange = NSRange(location: lineOffset + inner.location, length: inner.length)
            styleContent(contentRange)
        }
    }

    private static func applyTrait(_ trait: NSFontTraitMask, range: NSRange, storage: NSTextStorage, baseFont: NSFont) {
        let current = (storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont) ?? baseFont
        storage.addAttribute(.font, value: NSFontManager.shared.convert(current, toHaveTrait: trait), range: range)
    }
}

/// [v1.5] ⌘Enter(제출/저장)·⌘B(굵게)를 텍스트뷰 자신이 처리한다. 예전엔 ⌘B가 SwiftUI 툴바
/// 버튼의 전역 keyboardShortcut이라 카드 인라인 수정 중에 눌러도 아래 컴포저에 `**`가
/// 들어갔다(실사용 버그). first responder인 이 뷰가 먼저 받으면 "지금 타이핑 중인 필드"에만
/// 적용된다. performKeyEquivalent와 keyDown 양쪽에서 잡는다 — 창의 키 이퀴벌런트 순회가 이
/// 뷰까지 오지 않는 경우에도 keyDown은 first responder에 반드시 도착한다(먼저 온 쪽이 소비하고
/// 이벤트는 하나뿐이라 이중 처리는 없다).
final class HanjjokTextView: NSTextView {
    /// ⌘Enter. nil이면 처리하지 않고 기본 동작에 맡긴다.
    var onCommandReturn: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 창의 키 이퀴벌런트 순회는 포커스와 무관하게 계층의 모든 뷰를 방문한다 — first responder일
        // 때만 잡아야 컴포저에서 친 ⌘Enter/⌘B를 화면에 떠 있는 카드 수정 필드가 가로채지 않는다.
        if window?.firstResponder === self, handleCommandKey(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleCommandKey(event) { return }
        super.keyDown(with: event)
    }

    private func handleCommandKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.control), !flags.contains(.option) else { return false }
        switch event.keyCode {
        case 36, 76:  // Return · 키패드 Enter
            guard let onCommandReturn else { return false }
            // 한글 조합 중이면 먼저 확정한다 — 컴포저 보내기 버튼(finalizeAndReadText)과 같은 이유.
            if hasMarkedText() { unmarkText() }
            onCommandReturn()
            return true
        default:
            guard !flags.contains(.shift), event.charactersIgnoringModifiers?.lowercased() == "b" else { return false }
            ComposerCommands.wrapSelection(in: self, with: "**")
            return true
        }
    }
}
