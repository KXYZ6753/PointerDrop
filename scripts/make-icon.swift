#!/usr/bin/env swift
// Draws the "Night" app icon and writes AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift PointerDrop/Assets.xcassets/AppIcon.appiconset
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.appiconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = CGFloat(px) / 1024
    let body = 824 * k, margin = 100 * k, s = body / 100
    let rgb = { (hex: UInt32, a: CGFloat) in
        CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: a)
    }

    // y-down, 100-unit space: the same coordinates as the SVG design.
    ctx.translateBy(x: margin, y: margin + body)
    ctx.scaleBy(x: s, y: -s)
    let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerWidth: 22.4, cornerHeight: 22.4, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -1.4), blur: 3, color: rgb(0x000000, 0.35))
    ctx.addPath(tile); ctx.setFillColor(rgb(0x0D131A, 1)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0x3A4A5C, 1), rgb(0x0D131A, 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 100), options: [])
    ctx.restoreGState()

    // Rain streaks: x, y1, y2, opacity.
    ctx.setLineCap(.round); ctx.setLineWidth(3)
    for (x, y1, y2, a) in [(50, 6, 30, 1.0), (40, 12, 30, 0.6), (60, 10, 30, 0.6), (30, 20, 32, 0.35),
                           (70, 18, 32, 0.35), (21, 28, 36, 0.2), (79, 26, 36, 0.2)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
        ctx.setStrokeColor(rgb(0x9FB4C9, a))
        ctx.move(to: CGPoint(x: x, y: y1)); ctx.addLine(to: CGPoint(x: x, y: y2)); ctx.strokePath()
    }

    // Symmetric cursor dart, tip down.
    ctx.translateBy(x: 50, y: 58); ctx.scaleBy(x: 1.25, y: 1.25)
    ctx.move(to: CGPoint(x: 0, y: 22)); ctx.addLine(to: CGPoint(x: -13, y: -12))
    ctx.addLine(to: CGPoint(x: 0, y: -5)); ctx.addLine(to: CGPoint(x: 13, y: -12)); ctx.closePath()
    ctx.setFillColor(rgb(0xE8F1FA, 1)); ctx.setStrokeColor(rgb(0xE8F1FA, 1))
    ctx.setLineWidth(2.4); ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)

    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try render(base * scale).write(to: out.appending(path: name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: out.appending(path: "Contents.json"))
