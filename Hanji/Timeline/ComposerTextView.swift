import SwiftUI
import AppKit

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
                    return false
                }
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}
