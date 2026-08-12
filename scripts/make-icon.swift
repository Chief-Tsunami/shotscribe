#!/usr/bin/env swift
// Renders the ShotScribe app icon: a macOS-style squircle with an
// indigo→violet gradient and the text.viewfinder glyph, exported as an
// .iconset + .icns into assets/. Run via scripts/make-icon.sh; the result is
// committed so builders don't need to regenerate.
import AppKit

let master = 1024
let out = URL(fileURLWithPath: "assets", isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

// MARK: draw the 1024 master

let image = NSImage(size: NSSize(width: master, height: master), flipped: false) { rect in
    // Apple's icon grid: an ~824pt squircle centered on a 1024 canvas.
    let inset = CGFloat(100)
    let shape = rect.insetBy(dx: inset, dy: inset)
    let path = NSBezierPath(roundedRect: shape, xRadius: 185, yRadius: 185)

    // Soft drop shadow behind the squircle.
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(calibratedRed: 0.24, green: 0.23, blue: 0.65, alpha: 1).setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Gradient: indigo → deep violet, diagonal.
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.42, green: 0.40, blue: 0.95, alpha: 1),  // indigo
        NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.55, alpha: 1),  // deep violet
    ])
    gradient?.draw(in: path, angle: -60)

    // Subtle top sheen.
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.18),
        NSColor.white.withAlphaComponent(0.0),
    ])
    let sheenRect = NSRect(x: shape.minX, y: shape.midY, width: shape.width, height: shape.height / 2)
    let sheenPath = NSBezierPath(roundedRect: sheenRect, xRadius: 185, yRadius: 185)
    sheenPath.append(path)
    NSGraphicsContext.current?.saveGraphicsState()
    path.addClip()
    sheen?.draw(in: sheenRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // The glyph: text.viewfinder, white.
    let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size, flipped: false) { r in
            symbol.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        // Center, scaled to ~56% of the canvas, preserving the symbol's aspect.
        let target = CGFloat(master) * 0.56
        let aspect = symbol.size.width / symbol.size.height
        let w = aspect >= 1 ? target : target * aspect
        let h = aspect >= 1 ? target / aspect : target
        let glyphRect = NSRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h)
        tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    return true
}

// MARK: export the iconset

func png(_ image: NSImage, pixels: Int, to url: URL) {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
               from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
}

let iconset = out.appendingPathComponent("ShotScribe.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in sizes {
    png(image, pixels: px, to: iconset.appendingPathComponent(name))
}
print("iconset written to \(iconset.path) — now run iconutil")
