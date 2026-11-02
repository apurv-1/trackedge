// Draws the TrackEdge app icon and writes Support/AppIcon.icns.
// Run with: swift scripts/make-icon.swift
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha)
}

func withShadow(_ shadowColor: NSColor, blur: CGFloat, offsetY: CGFloat = 0, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func capsule(_ rect: NSRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.width / 2)
}

func drawIcon() {
    // macOS icon grid: an 824 pt tile centered on the 1024 canvas.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    withShadow(NSColor.black.withAlphaComponent(0.45), blur: 36, offsetY: -14) {
        color(0x0B0D12).setFill()
        tilePath.fill()
    }

    // Midnight base with a soft light falling from the top.
    NSGradient(starting: color(0x1F2331), ending: color(0x07080C))!.draw(in: tilePath, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(starting: color(0x8FA4FF, 0.22), ending: color(0x8FA4FF, 0))!
        .draw(fromCenter: CGPoint(x: 512, y: 900), radius: 0, toCenter: CGPoint(x: 512, y: 900), radius: 620, options: [])
    NSGraphicsContext.restoreGraphicsState()

    // Hairline rim so the tile reads as glass on dark wallpapers.
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    rim.lineWidth = 3
    color(0xFFFFFF, 0.10).setStroke()
    rim.stroke()

    // Trackpad slab: dark glass with a lit top edge and a shadow beneath.
    let pad = NSRect(x: 212, y: 318, width: 600, height: 392)
    let padPath = NSBezierPath(roundedRect: pad, xRadius: 60, yRadius: 60)
    withShadow(NSColor.black.withAlphaComponent(0.6), blur: 40, offsetY: -18) {
        color(0x1A1D26).setFill()
        padPath.fill()
    }
    NSGradient(starting: color(0x343948), ending: color(0x171A22))!.draw(in: padPath, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    padPath.addClip()
    let ring = NSBezierPath(roundedRect: pad, xRadius: 60, yRadius: 60)
    ring.append(NSBezierPath(roundedRect: pad.insetBy(dx: 3, dy: 3), xRadius: 57, yRadius: 57))
    ring.windingRule = .evenOdd
    NSGradient(starting: color(0xFFFFFF, 0.45), ending: color(0xFFFFFF, 0.04))!.draw(in: ring, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Left edge: brightness, a faint warm strip at rest.
    let left = NSRect(x: 258, y: 372, width: 22, height: 284)
    color(0xFFFFFF, 0.07).setFill()
    capsule(left).fill()
    let leftLevel = NSRect(x: 258, y: 372, width: 22, height: 120)
    withShadow(color(0xFFB340, 0.55), blur: 22) {
        color(0xFFB340).setFill()
        capsule(leftLevel).fill()
    }
    NSGradient(starting: color(0xFF8A00), ending: color(0xFFD25A))!.draw(in: capsule(leftLevel), angle: 90)

    // Right edge: volume, lit and glowing under the finger.
    let right = NSRect(x: 744, y: 372, width: 22, height: 284)
    color(0xFFFFFF, 0.07).setFill()
    capsule(right).fill()
    let level = NSRect(x: 744, y: 372, width: 22, height: 214)
    let levelGradient = NSGradient(starting: color(0x5E5CE6), ending: color(0x64D2FF))!
    withShadow(color(0x64D2FF, 0.9), blur: 34) {
        color(0x64D2FF).setFill()
        capsule(level).fill()
    }
    levelGradient.draw(in: capsule(level), angle: 90)

    // Fingertip: a frosted disc resting on the top of the level.
    let tip = CGPoint(x: 755, y: 586)
    let disc = NSBezierPath(ovalIn: NSRect(x: tip.x - 42, y: tip.y - 42, width: 84, height: 84))
    withShadow(color(0x64D2FF, 0.75), blur: 60) {
        color(0xFFFFFF).setFill()
        disc.fill()
    }
    withShadow(NSColor.black.withAlphaComponent(0.35), blur: 14, offsetY: -6) {
        color(0xFFFFFF).setFill()
        disc.fill()
    }
    NSGradient(starting: color(0xFFFFFF), ending: color(0xD6DEF0))!.draw(in: disc, angle: -90)
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(pixels) / canvas
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(pixels: 1024).write(to: root.appendingPathComponent("Support/AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
