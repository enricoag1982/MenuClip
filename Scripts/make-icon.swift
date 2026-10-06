// Draws the app icon into an .iconset folder for iconutil.
// Usage: swift Scripts/make-icon.swift build/AppIcon.iconset
import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.iconset>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    let size = CGFloat(pixels)
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    // Rounded square on Apple's icon grid (824 of 1024 points).
    let inset = size * 100 / 1024
    let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    NSGradient(
        starting: NSColor(calibratedRed: 0.38, green: 0.60, blue: 1.00, alpha: 1),
        ending: NSColor(calibratedRed: 0.17, green: 0.32, blue: 0.86, alpha: 1)
    )?.draw(in: shape, angle: -90)

    let configuration = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) {
        let white = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        let origin = NSPoint(x: (size - white.size.width) / 2, y: (size - white.size.height) / 2)
        white.draw(in: NSRect(origin: origin, size: white.size))
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in sizes {
    guard let png = renderIcon(pixels: pixels) else {
        FileHandle.standardError.write(Data("could not render \(name)\n".utf8))
        exit(1)
    }
    try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
}
