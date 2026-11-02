// Draws the 1200x630 social preview image at web/public/og.jpg.
// Run from web/: swift scripts/make-og.swift
import AppKit
import CoreText

let size = NSSize(width: 1200, height: 630)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// Loads Geist from the installed font package at the given weight on its variable axis.
func geist(_ pointSize: CGFloat, weight: CGFloat) -> NSFont {
    let file = root.appendingPathComponent("node_modules/@fontsource-variable/geist/files/geist-latin-wght-normal.woff2")
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(file as CFURL) as? [CTFontDescriptor],
          let base = descriptors.first else {
        fatalError("Geist not found. Run npm install in web/ first.")
    }
    let weightAxis = 0x7767_6874 // 'wght'
    let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, [
        kCTFontVariationAttribute: [weightAxis: weight],
    ] as CFDictionary)
    return CTFontCreateWithFontDescriptor(descriptor, pointSize, nil) as NSFont
}

func draw() {
    let bounds = NSRect(origin: .zero, size: size)
    NSGradient(starting: color(0x10131D), ending: color(0x05060A))!.draw(in: bounds, angle: -90)

    // Soft light behind the icon, in the site's accent colors.
    for (center, hex, radius, alpha) in [
        (CGPoint(x: 1010, y: 330), 0x64D2FF as UInt32, 420.0, 0.22),
        (CGPoint(x: 880, y: 160), 0x5E5CE6 as UInt32, 380.0, 0.2),
        (CGPoint(x: 1150, y: 60), 0xFFB340 as UInt32, 240.0, 0.07),
    ] {
        NSGradient(starting: color(hex, alpha), ending: color(hex, 0))!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }

    if let icon = NSImage(contentsOf: root.appendingPathComponent("public/app-icon.png")) {
        icon.draw(in: NSRect(x: 760, y: 105, width: 420, height: 420))
    }

    let title = NSAttributedString(string: "TrackEdge", attributes: [
        .font: geist(124, weight: 650), .foregroundColor: color(0xF2F4F8), .kern: -7,
    ])
    title.draw(at: CGPoint(x: 72, y: 300))

    let tagline = NSMutableParagraphStyle()
    tagline.lineSpacing = 6
    NSAttributedString(string: "Volume and brightness on\nyour trackpad's edges.", attributes: [
        .font: geist(44, weight: 420), .foregroundColor: color(0xF2F4F8, 0.7), .kern: -1.4, .paragraphStyle: tagline,
    ]).draw(in: NSRect(x: 76, y: 150, width: 680, height: 130))

    NSAttributedString(string: "Free and open source for macOS", attributes: [
        .font: geist(24, weight: 500), .foregroundColor: color(0x64D2FF), .kern: -0.3,
    ]).draw(at: CGPoint(x: 78, y: 88))
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
draw()
try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
    .write(to: root.appendingPathComponent("public/og.jpg"))
