// Generates the MirrorDesk app icon as an .iconset directory.
// Usage: make-icon <output.iconset>
import Cocoa

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

// background
let bgRect = NSRect(x: 36, y: 36, width: S - 72, height: S - 72)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 205, yRadius: 205)
let grad = NSGradient(colors: [
    NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.16, alpha: 1.0),
    NSColor(calibratedRed: 0.07, green: 0.26, blue: 0.78, alpha: 1.0),
    NSColor(calibratedRed: 0.13, green: 0.78, blue: 0.94, alpha: 1.0)
], atLocations: [0.0, 0.52, 1.0], colorSpace: .deviceRGB)!
grad.draw(in: bg, angle: -58)

let edge = NSBezierPath(roundedRect: bgRect.insetBy(dx: 2, dy: 2), xRadius: 203, yRadius: 203)
NSColor.white.withAlphaComponent(0.12).setStroke()
edge.lineWidth = 3
edge.stroke()

// shelf shadow
let shelfShadow = NSShadow()
shelfShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shelfShadow.shadowBlurRadius = 26
shelfShadow.shadowOffset = NSSize(width: 0, height: -8)

// glass shelf
let deskRect = NSRect(x: S / 2 - 370, y: 178, width: 740, height: 38)
let desk = NSBezierPath(roundedRect: deskRect, xRadius: 19, yRadius: 19)
NSGraphicsContext.saveGraphicsState()
shelfShadow.set()
NSColor.white.withAlphaComponent(0.30).setFill()
desk.fill()
NSGraphicsContext.restoreGraphicsState()

let deskEdge = NSRect(x: deskRect.minX + 14, y: deskRect.maxY - 4, width: deskRect.width - 28, height: 4)
NSColor.white.withAlphaComponent(0.80).setFill()
NSBezierPath(roundedRect: deskEdge, xRadius: 2, yRadius: 2).fill()

// phone
let phoneRect = NSRect(x: S / 2 - 190, y: 206, width: 380, height: 666)
let phone = NSBezierPath(roundedRect: phoneRect, xRadius: 78, yRadius: 78)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.50)
shadow.shadowBlurRadius = 54
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.set()
let bodyGrad = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 1.0),
    NSColor(calibratedWhite: 0.82, alpha: 1.0)
])!
bodyGrad.draw(in: phone, angle: -90)
NSGraphicsContext.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.60).setStroke()
phone.lineWidth = 3
phone.stroke()

// screen
let screenRect = phoneRect.insetBy(dx: 24, dy: 24)
let screen = NSBezierPath(roundedRect: screenRect, xRadius: 56, yRadius: 56)
let screenGrad = NSGradient(colors: [
    NSColor(calibratedRed: 0.025, green: 0.045, blue: 0.12, alpha: 1.0),
    NSColor(calibratedRed: 0.05, green: 0.13, blue: 0.30, alpha: 1.0)
])!
screenGrad.draw(in: screen, angle: -90)

// centered desktop window
let winRect = NSRect(x: screenRect.minX + 46, y: screenRect.midY - 145, width: screenRect.width - 92, height: 290)
let win = NSBezierPath(roundedRect: winRect, xRadius: 24, yRadius: 24)
NSColor.white.withAlphaComponent(0.24).setFill()
win.fill()
NSColor.white.withAlphaComponent(0.50).setStroke()
win.lineWidth = 2
win.stroke()

let titleBar = NSRect(x: winRect.minX, y: winRect.maxY - 44, width: winRect.width, height: 44)
NSColor.white.withAlphaComponent(0.55).setFill()
NSBezierPath(roundedRect: titleBar, xRadius: 22, yRadius: 22).fill()

for i in 0..<3 {
    let dot = NSRect(x: titleBar.minX + 20 + CGFloat(i) * 18, y: titleBar.midY - 5.5, width: 11, height: 11)
    NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.22, alpha: 0.85).setFill()
    NSBezierPath(ovalIn: dot).fill()
}

// one line of "content" inside the window
let content = NSRect(x: winRect.minX + 22, y: winRect.minY + 34, width: winRect.width - 44, height: 14)
NSColor.white.withAlphaComponent(0.35).setFill()
NSBezierPath(roundedRect: content, xRadius: 7, yRadius: 7).fill()

img.unlockFocus()

func save(_ px: Int, _ path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/MirrorDesk.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
save(16, "\(dir)/icon_16x16.png")
save(32, "\(dir)/icon_16x16@2x.png")
save(32, "\(dir)/icon_32x32.png")
save(64, "\(dir)/icon_32x32@2x.png")
save(128, "\(dir)/icon_128x128.png")
save(256, "\(dir)/icon_128x128@2x.png")
save(256, "\(dir)/icon_256x256.png")
save(512, "\(dir)/icon_256x256@2x.png")
save(512, "\(dir)/icon_512x512.png")
save(1024, "\(dir)/icon_512x512@2x.png")
print("icon written to \(dir)")
