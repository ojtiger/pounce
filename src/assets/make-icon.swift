import AppKit

// Renders every CentreGrowl icon from one paw drawing (paw-source.png, black paw, any background):
//   <iconset dir>   the app icon: a white paw on a baked blue-violet squircle, all macOS sizes
//   paw-mask.png    the paw alone as a black shape with alpha, shipped in the bundle for the menu bar
// Usage: swift make-icon.swift <iconset dir>

let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let out = CommandLine.arguments[1]

/// The paw as a black CGImage with alpha, whatever the source's background was:
/// alpha = source alpha × darkness, so white or transparent both fall away.
func pawMask() -> CGImage {
  let source = NSImage(contentsOf: here.appendingPathComponent("paw-source.png"))!
  let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  let w = cg.width, h = cg.height
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
  let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
  for i in stride(from: 0, to: w * h * 4, by: 4) {
    let a = CGFloat(px[i + 3]) / 255
    // un-premultiply to judge darkness
    let lum = a > 0 ? (0.299 * CGFloat(px[i]) + 0.587 * CGFloat(px[i + 1]) + 0.114 * CGFloat(px[i + 2])) / (255 * a) : 1
    let alpha = UInt8(max(0, min(255, (a * (1 - min(1, lum))) * 255)))
    px[i] = 0; px[i + 1] = 0; px[i + 2] = 0; px[i + 3] = alpha
  }
  return ctx.makeImage()!
}

let mask = pawMask()
let maskImage = NSImage(cgImage: mask, size: NSSize(width: mask.width, height: mask.height))

/// The paw tinted, drawn to fit `rect`, keeping its aspect.
func drawPaw(in rect: NSRect, color: NSColor) {
  let bounds = CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
  let k = min(rect.width / bounds.width, rect.height / bounds.height)
  let size = NSSize(width: bounds.width * k, height: bounds.height * k)
  let at = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
  let ctx = NSGraphicsContext.current!.cgContext
  ctx.saveGState()
  ctx.clip(to: at, mask: mask)
  color.setFill()
  at.fill()
  ctx.restoreGState()
}

/// macOS app icon: the rounded square fills 80 % of the canvas, with a soft baked shadow like Apple's own.
func renderAppIcon(_ size: CGFloat) -> NSImage {
  NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    let s = size
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = rect.width * 0.225
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Drop shadow
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.black.setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Baked background: violet to blue, lit from the top left
    NSGradient(colors: [
      NSColor(calibratedRed: 0.50, green: 0.36, blue: 1.00, alpha: 1),
      NSColor(calibratedRed: 0.26, green: 0.47, blue: 1.00, alpha: 1),
      NSColor(calibratedRed: 0.13, green: 0.36, blue: 0.92, alpha: 1),
    ])!.draw(in: squircle, angle: -60)
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
      .draw(in: NSBezierPath(ovalIn: NSRect(x: rect.minX - rect.width * 0.2, y: rect.midY,
                                            width: rect.width * 1.1, height: rect.height * 0.9)),
            relativeCenterPosition: NSPoint(x: -0.3, y: 0.5))
    NSGraphicsContext.restoreGraphicsState()

    // The paw, white, with a little lift
    NSGraphicsContext.saveGraphicsState()
    let lift = NSShadow()
    lift.shadowColor = NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.45, alpha: 0.45)
    lift.shadowBlurRadius = s * 0.025
    lift.shadowOffset = NSSize(width: 0, height: -s * 0.015)
    lift.set()
    drawPaw(in: rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.2), color: .white)
    NSGraphicsContext.restoreGraphicsState()

    // Glass rim
    NSColor.white.withAlphaComponent(0.22).setStroke()
    squircle.lineWidth = max(1, s * 0.006)
    squircle.stroke()
    return true
  }
}

func writePNG(_ image: NSImage, px: Int, to path: String) {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = NSSize(width: px, height: px)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
  NSGraphicsContext.restoreGraphicsState()
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let specs: [(String, Int)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs { writePNG(renderAppIcon(CGFloat(px)), px: px, to: "\(out)/\(name).png") }
writePNG(maskImage, px: mask.width, to: here.appendingPathComponent("paw-mask.png").path)
print("iconset written to \(out), paw-mask.png updated")
