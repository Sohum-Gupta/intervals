// Draws the app icon: a minimalist analog clock in the app's own language —
// dark card, accent ring, two hands. Run: make icon
import AppKit

let canvas: CGFloat = 1024
let accent = NSColor(srgbRed: 0.98, green: 0.42, blue: 0.40, alpha: 1)

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / canvas
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)

    // Card: Apple's icon grid keeps content inside an 824 pt rounded square.
    let inset = 100 * s
    let card = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: 186 * s, yRadius: 186 * s)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(srgbRed: 0.13, green: 0.14, blue: 0.16, alpha: 1).setFill()
    cardPath.fill()
    NSGraphicsContext.restoreGraphicsState()
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.19, green: 0.20, blue: 0.23, alpha: 1),
        ending: NSColor(srgbRed: 0.11, green: 0.12, blue: 0.14, alpha: 1)
    )!
    gradient.draw(in: cardPath, angle: -90)

    // Ring: the timer ring, three quarters remaining, track behind it.
    let center = NSPoint(x: size / 2, y: size / 2)
    let radius = 272 * s
    let ringWidth = 58 * s
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = ringWidth
    accent.withAlphaComponent(0.18).setStroke()
    track.stroke()
    let ring = NSBezierPath()
    // Clockwise from 12 o'clock: AppKit angles run counter-clockwise from 3 o'clock.
    ring.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 180, clockwise: true)
    ring.lineWidth = ringWidth
    ring.lineCapStyle = .round
    accent.setStroke()
    ring.stroke()

    // Hands at ten past ten, white, rounded.
    func hand(angleDegrees: CGFloat, length: CGFloat, width: CGFloat) {
        let rad = angleDegrees * .pi / 180
        let end = NSPoint(x: center.x + cos(rad) * length, y: center.y + sin(rad) * length)
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: end)
        path.lineWidth = width
        path.lineCapStyle = .round
        NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1).setStroke()
        path.stroke()
    }
    hand(angleDegrees: 150, length: 118 * s, width: 44 * s)   // hour hand toward 10
    hand(angleDegrees: 60, length: 178 * s, width: 34 * s)    // minute hand toward 2
    let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 30 * s, y: center.y - 30 * s, width: 60 * s, height: 60 * s))
    accent.setFill()
    dot.fill()
    let pin = NSBezierPath(ovalIn: NSRect(x: center.x - 11 * s, y: center.y - 11 * s, width: 22 * s, height: 22 * s))
    NSColor(srgbRed: 0.13, green: 0.14, blue: 0.16, alpha: 1).setFill()
    pin.fill()

    image.unlockFocus()
    return image
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let image = draw(size: CGFloat(size))
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: outDir.appendingPathComponent("icon_\(size).png"))
}
print("wrote icons to \(outDir.path)")
