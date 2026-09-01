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
        let textView = scroll.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextView
        init(_ parent: ComposerTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
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
}
