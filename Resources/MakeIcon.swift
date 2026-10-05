import AppKit

// A code-drawn icon: no external artwork or asset dependencies.
func png(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let body = NSBezierPath(roundedRect: NSRect(x: 30, y: 30, width: 964, height: 964), xRadius: 215, yRadius: 215)
    NSGradient(starting: NSColor(red: 0.19, green: 0.36, blue: 0.94, alpha: 1),
               ending: NSColor(red: 0.37, green: 0.18, blue: 0.80, alpha: 1))!.draw(in: body, angle: 55)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 352, y: 222, width: 320, height: 530), xRadius: 155, yRadius: 155).fill()
    NSColor(red: 0.29, green: 0.30, blue: 0.88, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 482, y: 603, width: 60, height: 100), xRadius: 30, yRadius: 30).fill()
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    ("T" as NSString).draw(in: NSRect(x: 352, y: 317, width: 320, height: 170), withAttributes: [
        .font: NSFont.systemFont(ofSize: 155, weight: .heavy),
        .foregroundColor: NSColor(red: 0.29, green: 0.30, blue: 0.88, alpha: 1),
        .paragraphStyle: paragraph
    ])
    for x: CGFloat in [185, 839] {
        let sign: CGFloat = x < 512 ? -1 : 1
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x - sign * 40, y: 528))
        path.line(to: NSPoint(x: x, y: 488))
        path.line(to: NSPoint(x: x - sign * 40, y: 448))
        path.lineWidth = 24
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

func integer(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return Data(bytes: &bigEndian, count: 4)
}
var chunks = Data()
for (type, size) in [("ic08", 256), ("ic09", 512), ("ic10", 1024)] {
    let data = png(size: size)
    chunks.append(type.data(using: .ascii)!)
    chunks.append(integer(data.count + 8))
    chunks.append(data)
}
var icon = "icns".data(using: .ascii)!
icon.append(integer(chunks.count + 8))
icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
