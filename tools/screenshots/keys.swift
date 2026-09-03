import AppKit
// 특정 프로세스에만 키 이벤트를 꽂는다 (활성화 불필요, 다른 앱엔 절대 전달 안 됨)
// usage: swift keys.swift <pid> text "<string>"
//        swift keys.swift <pid> key <keycode> [cmd] [shift] [chars=f]
//        단축키는 chars= 로 문자를 명시할 것 — 비우면 현재 입력기(한글)로 문자가 채워져
//        SwiftUI KeyEquivalent 매칭에 실패하고 텍스트뷰에 자모가 입력된다.
let a = CommandLine.arguments
let pid = pid_t(a[1])!
let src = CGEventSource(stateID: .hidSystemState)
if a[2] == "text" {
    for scalar in a[3].unicodeScalars {
        var u = Array(String(scalar).utf16)
        let d = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)!
        d.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u); d.postToPid(pid)
        let x = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)!
        x.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u); x.postToPid(pid)
        usleep(9000)
    }
} else {
    let code = CGKeyCode(UInt16(a[3])!)
    var f: CGEventFlags = []
    if a.contains("cmd") { f.insert(.maskCommand) }
    if a.contains("shift") { f.insert(.maskShift) }
    let chars = a.first(where: { $0.hasPrefix("chars=") }).map { String($0.dropFirst(6)) }
    let d = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)!; d.flags = f
    let x = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!; x.flags = f
    if let c = chars { var u = Array(c.utf16); d.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u); x.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u) }
    d.postToPid(pid); usleep(20000); x.postToPid(pid)
}
usleep(50000)
