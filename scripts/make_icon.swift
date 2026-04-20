#!/usr/bin/env swift
import AppKit

let outputDir = "Hermes/Assets.xcassets/AppIcon.appiconset"
let sizes = [16, 32, 128, 256, 512]

for size in sizes {
    for scale in [1, 2] {
        let px = size * scale
        let image = NSImage(size: NSSize(width: px, height: px), flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: CGFloat(px) * 0.45, weight: .medium)
            let symbol = NSImage(systemSymbolName: "clipboard", accessibilityDescription: nil)!
                .withSymbolConfiguration(config)!

            NSColor.black.setFill()
            let bg = NSBezierPath(roundedRect: rect, xRadius: CGFloat(px) * 0.22, yRadius: CGFloat(px) * 0.22)
            bg.fill()

            let symSize = symbol.size
            let origin = NSPoint(
                x: (rect.width - symSize.width) / 2,
                y: (rect.height - symSize.height) / 2
            )
            let coloredSymbol = symbol.copy() as! NSImage
            coloredSymbol.lockFocus()
            NSColor.white.set()
            NSRect(origin: .zero, size: coloredSymbol.size).fill(using: .sourceAtop)
            coloredSymbol.unlockFocus()
            coloredSymbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }

        let suffix = scale == 1 ? "" : "@2x"
        let filename = "\(outputDir)/icon_\(size)x\(size)\(suffix).png"
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let png = rep.representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: filename))
        print("wrote \(filename)")
    }
}
