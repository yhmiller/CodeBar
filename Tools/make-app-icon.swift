#!/usr/bin/env swift
//
// Renders CodeBar's app icon and writes the .appiconset.
//
// The icon is generated rather than hand-drawn so it stays in step with the menu
// bar symbol: same stethoscope glyph, on the rounded-square ground macOS expects.
// Re-run with `make icon` after changing anything here.
//
import AppKit

let SYMBOL = "stethoscope"
let SIZES: [(size: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2)
]

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// Apple's icon grid insets the artwork inside the rounded square rather than
/// filling it edge to edge.
func drawIcon(pixels: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let side = CGFloat(pixels)
    let inset = side * 0.06
    let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let corner = plate.width * 0.2237  // matches the macOS squircle closely enough

    let background = NSBezierPath(roundedRect: plate, xRadius: corner, yRadius: corner)
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.20, green: 0.42, blue: 0.86, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.60, alpha: 1)
        ]
    )
    gradient?.draw(in: background, angle: -90)

    let glyphSize = plate.width * 0.58
    let configuration = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .medium)
    guard let symbol = NSImage(systemSymbolName: SYMBOL, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration) else { return rep }

    let tinted = NSImage(size: symbol.size, flipped: false) { rect in
        NSColor.white.set()
        rect.fill()
        symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
        return true
    }

    let glyphRect = NSRect(
        x: plate.midX - tinted.size.width / 2,
        y: plate.midY - tinted.size.height / 2,
        width: tinted.size.width,
        height: tinted.size.height
    )
    tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 0.96)

    return rep
}

var images: [[String: String]] = []

for (size, scale) in SIZES {
    let pixels = size * scale
    guard let rep = drawIcon(pixels: pixels),
          let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to render \(pixels)px\n".utf8))
        exit(1)
    }
    let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try data.write(to: output.appending(path: name))
    images.append([
        "size": "\(size)x\(size)",
        "idiom": "mac",
        "filename": name,
        "scale": "\(scale)x"
    ])
}

let contents: [String: Any] = [
    "images": images,
    "info": ["version": 1, "author": "make-app-icon.swift"]
]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appending(path: "Contents.json"))

print("wrote \(images.count) icon sizes to \(output.path)")
