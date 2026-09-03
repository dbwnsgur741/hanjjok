import AppKit
// usage: swift click.swift <x> <y> [clicks]
// HID 탭에 실제 마우스 이동+클릭을 넣는다(clicks=2면 더블클릭, 0이면 이동만). 실제 커서가 움직이므로
// 끝나면 원래 위치로 되돌릴 것(before 좌표를 출력한다). 호스트 앱에 손쉬운 접근 권한이 있어야 하며,
// CGEvent.postToPid 마우스 이벤트는 SwiftUI 버튼/제스처에 닿지 않아(실측) 이 방식만 동작한다.
// 좌표는 CGWindow 전역 좌표(주 디스플레이 좌상단 원점) — winid.swift 출력과 같은 체계.
let a = CommandLine.arguments
let p = CGPoint(x: Double(a[1])!, y: Double(a[2])!); let clicks = a.count > 3 ? Int64(a[3])! : 1
let src = CGEventSource(stateID: .hidSystemState)
let before = CGEvent(source: nil)!.location
CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap)
usleep(150000)
let after = CGEvent(source: nil)!.location
print("cursor before", before, "after", after)
if clicks > 0 && abs(after.x - p.x) < 2 {
    for i in 1...clicks {
        let d = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)!
        let u = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)!
        d.setIntegerValueField(.mouseEventClickState, value: i); u.setIntegerValueField(.mouseEventClickState, value: i)
        d.post(tap: .cghidEventTap); usleep(50000); u.post(tap: .cghidEventTap); usleep(80000)
    }
    print("clicked", clicks)
}
