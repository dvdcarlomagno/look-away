#!/usr/bin/env swift
import AppKit
import CoreGraphics

let outputDirectory = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : URL(fileURLWithPath: "LookAway/Resources/AppIcon.iconset", isDirectory: true)

struct IconSpec {
    let filename: String
    let pixelSize: Int
}

private let iconSpecs: [IconSpec] = [
    IconSpec(filename: "icon_16x16.png", pixelSize: 16),
    IconSpec(filename: "icon_16x16@2x.png", pixelSize: 32),
    IconSpec(filename: "icon_32x32.png", pixelSize: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixelSize: 64),
    IconSpec(filename: "icon_128x128.png", pixelSize: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixelSize: 256),
    IconSpec(filename: "icon_256x256.png", pixelSize: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixelSize: 512),
    IconSpec(filename: "icon_512x512.png", pixelSize: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixelSize: 1024),
]

private func drawBubbleGumGradient(in context: CGContext, rect: CGRect) {
    let colors = [
        CGColor(red: 1.0, green: 0.36, blue: 0.74, alpha: 1.0),
        CGColor(red: 1.0, green: 0.56, blue: 0.84, alpha: 1.0),
        CGColor(red: 1.0, green: 0.74, blue: 0.90, alpha: 1.0),
    ] as CFArray
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: colors,
        locations: [0.0, 0.52, 1.0]
    ) else { return }

    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: rect.height),
        end: CGPoint(x: rect.width, y: 0),
        options: []
    )
}

private func renderIcon(pixelSize: Int) -> NSImage {
    let dimension = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))

    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else { return image }

    let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
    let cornerRadius = dimension * 0.224
    let clipPath = NSBezierPath(roundedRect: NSRect(origin: .zero, size: NSSize(width: dimension, height: dimension)), xRadius: cornerRadius, yRadius: cornerRadius)
    clipPath.addClip()

    drawBubbleGumGradient(in: context, rect: rect)

    let pointSize = max(8, dimension * 0.44)
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        .applying(.init(paletteColors: [.white]))

    guard
        let baseSymbol = NSImage(systemSymbolName: "eyes", accessibilityDescription: "Look Away"),
        let symbol = baseSymbol.withSymbolConfiguration(symbolConfig)
    else {
        return image
    }

    let symbolSize = symbol.size
    let origin = NSPoint(
        x: (dimension - symbolSize.width) / 2,
        y: (dimension - symbolSize.height) / 2
    )
    symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)

    return image
}

private func savePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "LookAwayIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try data.write(to: url, options: .atomic)
}

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    for spec in iconSpecs {
        let image = renderIcon(pixelSize: spec.pixelSize)
        let destination = outputDirectory.appendingPathComponent(spec.filename)
        try savePNG(image, to: destination)
    }

    fputs("Generated app icon PNGs in \(outputDirectory.path)\n", stderr)
} catch {
    fputs("Icon generation failed: \(error)\n", stderr)
    exit(1)
}
