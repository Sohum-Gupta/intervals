// Draws the Icon Composer layers for the liquid-glass icon: white shapes on
// transparent backgrounds, coloured by icon.json. Run: make icon
import AppKit

let canvas: CGFloat = 1024

func layer(_ name: String, to dir: URL, draw: (NSPoint, CGFloat) -> Void) {
    let size = Int(canvas)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.cgContext.setShouldAntialias(true)
    NSColor.white.set()
    draw(NSPoint(x: canvas / 2, y: canvas / 2), 1)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: dir.appendingPathComponent(name))
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let radius: CGFloat = 272
let ringWidth: CGFloat = 58

layer("track.png", to: outDir) { center, _ in
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    path.lineWidth = ringWidth
    path.stroke()
}
layer("ring.png", to: outDir) { center, _ in
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 180, clockwise: true)
    path.lineWidth = ringWidth
    path.lineCapStyle = .round
    path.stroke()
}
layer("hands.png", to: outDir) { center, _ in
    func hand(_ degrees: CGFloat, length: CGFloat, width: CGFloat) {
        let rad = degrees * .pi / 180
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: NSPoint(x: center.x + cos(rad) * length, y: center.y + sin(rad) * length))
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }
    hand(150, length: 118, width: 44)
    hand(60, length: 178, width: 34)
}
layer("dot.png", to: outDir) { center, _ in
    NSBezierPath(ovalIn: NSRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60)).fill()
    NSGraphicsContext.current!.cgContext.setBlendMode(.clear)
    NSBezierPath(ovalIn: NSRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22)).fill()
}
print("wrote layers to \(outDir.path)")
