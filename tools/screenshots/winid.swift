import AppKit
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let b = w[kCGWindowBounds as String] as! [String: CGFloat]
    print(w[kCGWindowNumber as String] as! Int, "\"\(w[kCGWindowOwnerName as String] as? String ?? "?")\"",
          Int(b["X"]!), Int(b["Y"]!), Int(b["Width"]!), Int(b["Height"]!), "layer", w[kCGWindowLayer as String] as? Int ?? 0)
}
