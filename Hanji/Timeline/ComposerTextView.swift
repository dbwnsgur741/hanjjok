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
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
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
        textView.font = font
        context.coordinator.reportHeight(from: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextView
        /// [QA r3 ②] 직전에 보고한 높이 — 0.5pt 미만 변화는 다시 보고하지 않아 SwiftUI 쪽
        /// height binding ↔ NSTextView 레이아웃 사이의 무한 갱신 루프를 막는다.
        private var lastReportedHeight: CGFloat?
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

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                // Shift+Enter는 줄바꿈으로 통과 — 단, 한 줄 모드(이름 필드)는 줄바꿈이 필요
                // 없으므로 항상 제출 처리한다.
                if !parent.singleLine, NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    return handleChecklistContinuation(in: textView)
                }
                parent.onSubmit()
                return true
            }
            return false
        }

        /// [QA r2] 체크리스트 연속 입력 — Shift+Enter를 누른 캐럿이 있는 현재 줄이 체크리스트
        /// 항목(본문 있음)이면 다음 줄에도 자동으로 `"[] "` 마커를 이어 붙여 매 줄 버튼을
        /// 다시 누르지 않아도 되게 한다. 마커만 있고 본문이 빈 줄(연속 입력을 끝내려는 신호)
        /// 이거나 애초에 체크리스트 항목이 아니면 일반 줄바꿈으로 통과시킨다(무한 마커 방지).
        /// 다중행 컴포저 전체(메인 컴포저 + NoteCardView 인라인 수정)가 이 경로를 공유한다 —
        /// singleLine 모드(DrawerView)는 위 분기에서 이미 걸러져 영향받지 않는다.
        private func handleChecklistContinuation(in textView: NSTextView) -> Bool {
            let ns = textView.string as NSString
            let caretRange = textView.selectedRange()
            let lineRange = ns.lineRange(for: caretRange)
            let currentLine = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
            guard let item = ChecklistParser.items(in: currentLine).first, !item.text.isEmpty else {
                return false
            }
            textView.insertText("\n[] ", replacementRange: caretRange)
            return true
        }
    }
}

/// [Task 24] 컴포저 체크리스트 버튼 → NSTextView 브릿지. ComposerTextView.makeNSView가
/// 생성 시 `textView`를 채워주면, SwiftUI 쪽 버튼 액션이 이 클래스를 통해 NSTextView에
/// 직접 마커를 삽입한다(SwiftUI에는 NSTextView의 selectedRange 등을 직접 만질 방법이 없음).
@MainActor
final class ComposerCommands {
    weak var textView: NSTextView?

    /// 캐럿이 있는 줄의 시작 위치에 체크리스트 마커 `"[] "`를 삽입한다.
    /// ChecklistParser의 lineRegex가 요구하는 정확한 문자열(대괄호 쌍 + 공백 1개)이어야
    /// 새 항목으로 인식된다.
    func insertChecklistMarker() {
        guard let textView else { return }
        let ns = textView.string as NSString
        let lineStart = ns.lineRange(for: textView.selectedRange()).location
        textView.insertText("[] ", replacementRange: NSRange(location: lineStart, length: 0))
    }

    /// 조합 중(marked) 텍스트를 확정하고 확정된 전체 문자열을 돌려준다.
    /// 보내기 버튼처럼 포커스를 뺏지 않는 경로는 전송 전 반드시 이걸 거쳐야
    /// 조합 중 글자 유실·잔여 텍스트가 없다 (QA r3 ⑤).
    func finalizeAndReadText() -> String? {
        guard let textView else { return nil }
        if textView.hasMarkedText() { textView.unmarkText() }
        return textView.string
    }
}
