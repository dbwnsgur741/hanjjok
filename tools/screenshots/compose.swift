import AppKit
import CoreText
// usage: swift compose.swift <panel.png> <out.png> <light|dark> "<title>" "<subtitle>"
// 2880×1800 캔버스(App Store Mac 규격)에 패널 캡처를 오른쪽에 얹고 왼쪽에 캡션.
let a = CommandLine.arguments
let panel = NSImage(contentsOfFile: a[1])!
let out = a[2], mode = a[3], title = a[4], sub = a[5]
let W = 2880, H = 1800
for f in ["MaruBuri-Bold.otf", "Pretendard-Regular.otf", "Pretendard-SemiBold.otf"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "Hanjjok/Resources/Fonts/\(f)") as CFURL, .process, nil)
}
func c(_ h: UInt32) -> NSColor { NSColor(calibratedRed: CGFloat((h>>16)&0xff)/255, green: CGFloat((h>>8)&0xff)/255, blue: CGFloat(h&0xff)/255, alpha: 1) }
let bg = mode == "dark" ? c(0x121110) : c(0xD8CFB8)
let fg = mode == "dark" ? c(0xE8E0CE) : c(0x2A2620)
let accent = mode == "dark" ? c(0x7EA6CE) : c(0x274C77)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
bg.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()

// 패널: 높이 맞춰 축소, 오른쪽 배치
let pr = panel.representations.first!
let pw = CGFloat(pr.pixelsWide), ph = CGFloat(pr.pixelsHigh)
let s = min(CGFloat(H - 180) / ph, 1.0)
let dw = pw * s, dh = ph * s
let px = CGFloat(W) - dw - 150, py = (CGFloat(H) - dh) / 2
NSGraphicsContext.current?.saveGraphicsState()
let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(mode == "dark" ? 0.65 : 0.35)
sh.shadowBlurRadius = 70; sh.shadowOffset = NSSize(width: 0, height: -24); sh.set()
panel.draw(in: NSRect(x: px, y: py, width: dw, height: dh), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.current?.restoreGraphicsState()

// 캡션
let para = NSMutableParagraphStyle(); para.lineSpacing = 10
let tFont = NSFont(name: "MaruBuri-Bold", size: 112) ?? NSFont.boldSystemFont(ofSize: 112)
let sFont = NSFont(name: "Pretendard-Regular", size: 48) ?? NSFont.systemFont(ofSize: 48)
let ts = NSAttributedString(string: title, attributes: [.font: tFont, .foregroundColor: fg, .paragraphStyle: para])
let ss = NSAttributedString(string: sub, attributes: [.font: sFont, .foregroundColor: fg.withAlphaComponent(0.72), .paragraphStyle: para])
let tx: CGFloat = 200, tw = px - tx - 140
let tb = ts.boundingRect(with: NSSize(width: tw, height: 1200), options: [.usesLineFragmentOrigin])
let sb = ss.boundingRect(with: NSSize(width: tw, height: 500), options: [.usesLineFragmentOrigin])
let gap: CGFloat = 44, totalH = tb.height + gap + sb.height
let top = (CGFloat(H) + totalH) / 2
ts.draw(with: NSRect(x: tx, y: top - tb.height, width: tw, height: tb.height), options: [.usesLineFragmentOrigin])
ss.draw(with: NSRect(x: tx, y: top - tb.height - gap - sb.height, width: tw, height: sb.height), options: [.usesLineFragmentOrigin])
accent.setFill(); NSRect(x: tx - 48, y: top - totalH, width: 14, height: totalH).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out) panel=\(Int(pw))x\(Int(ph)) scale=\(String(format: "%.2f", s))")
