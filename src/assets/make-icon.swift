import AppKit

// Renders the CentreGrowl app icon: a deep glass squircle with a centred, glowing card.
func render(_ size: CGFloat) -> NSImage {
  let img = NSImage(size: NSSize(width: size, height: size))
  img.lockFocus()
  let s = size
  let inset = s * 0.05
  let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
  let squircle = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)

  // Background gradient
  let bg = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.36, alpha: 1),
    NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.16, alpha: 1),
  ])!
  bg.draw(in: squircle, angle: -70)

  // Soft colour bloom behind the card
  let bloom = NSGradient(colors: [
    NSColor(calibratedRed: 0.35, green: 0.55, blue: 1.0, alpha: 0.85),
    NSColor(calibratedRed: 0.55, green: 0.35, blue: 1.0, alpha: 0.35),
    NSColor(calibratedRed: 0.35, green: 0.55, blue: 1.0, alpha: 0.0),
  ])!
  squircle.addClip()
  bloom.draw(in: NSBezierPath(ovalIn: NSRect(x: s * 0.1, y: s * 0.12, width: s * 0.8, height: s * 0.8)),
             relativeCenterPosition: NSPoint(x: 0, y: 0.1))

  // The card: a centred glass rectangle
  let card = NSRect(x: s * 0.2, y: s * 0.34, width: s * 0.6, height: s * 0.32)
  let cardPath = NSBezierPath(roundedRect: card, xRadius: s * 0.08, yRadius: s * 0.08)
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
  shadow.shadowBlurRadius = s * 0.05
  shadow.shadowOffset = NSSize(width: 0, height: -s * 0.025)
  shadow.set()
  NSColor.white.withAlphaComponent(0.92).setFill()
  cardPath.fill()
  NSShadow().set()

  // Card content: a dot (app colour) and two text lines
  NSColor(calibratedRed: 0.3, green: 0.5, blue: 1.0, alpha: 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: card.minX + s * 0.06, y: card.midY - s * 0.045, width: s * 0.09, height: s * 0.09)).fill()
  NSColor(calibratedWhite: 0.15, alpha: 0.85).setFill()
  NSBezierPath(roundedRect: NSRect(x: card.minX + s * 0.19, y: card.midY + s * 0.01, width: s * 0.3, height: s * 0.05),
               xRadius: s * 0.025, yRadius: s * 0.025).fill()
  NSColor(calibratedWhite: 0.15, alpha: 0.4).setFill()
  NSBezierPath(roundedRect: NSRect(x: card.minX + s * 0.19, y: card.midY - s * 0.07, width: s * 0.22, height: s * 0.045),
               xRadius: s * 0.0225, yRadius: s * 0.0225).fill()

  // Glass rim on the squircle
  NSColor.white.withAlphaComponent(0.25).setStroke()
  squircle.lineWidth = max(1, s * 0.01)
  squircle.stroke()
  img.unlockFocus()
  return img
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let specs: [(String, CGFloat)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
  let img = render(px)
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = NSSize(width: px, height: px)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
  NSGraphicsContext.restoreGraphicsState()
  let png = rep.representation(using: .png, properties: [:])!
  try! png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("iconset written")
