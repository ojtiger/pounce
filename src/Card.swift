import AppKit
import QuartzCore

enum Style {
  /// The user's size setting: everything about the card scales with it, except the transparent margin.
  static var scale: CGFloat { Settings.shared.size.scale }
  static var width: CGFloat { 480 * scale }
  /// Transparent margin around the card so the pop overshoot and shadow are not clipped.
  static let margin: CGFloat = 56
  static var padding: CGFloat { 22 * scale }
  static var iconSize: CGFloat { 56 * scale }
  static var corner: CGFloat { 28 * scale }
  static var gap: CGFloat { 14 * scale }
  /// Distance from the screen edge for the corner anchors.
  static let edgeInset: CGFloat = 24
  /// How long a banner card stays, from the settings; the ring counts it down.
  static var showSeconds: TimeInterval { Settings.shared.duration }
  static let maxGroups = 3
  /// The mark that stands for one notification: a filled dot that empties over the time it has left.
  static var dotSize: CGFloat { 11 * scale }
  static let maxHistory = 3
}

// MARK: - Palette

/// Colours for one card, derived from the app icon and the system appearance at that moment.
struct Palette {
  let isDark: Bool
  let tint: NSColor
  let warm: NSColor
  let cool: NSColor
  let text: NSColor
  let textSecondary: NSColor
  let textTertiary: NSColor
  let rim: [NSColor]
  let pillFill: NSColor
  let pillHover: NSColor
  let pillPressed: NSColor
  let pillBorder: NSColor
  let sweep: NSColor
  let blobAlpha: CGFloat
  let wash: NSColor
  /// The opaque card colour, for when the desktop is not to show through. Tinted by the app's hue
  /// so a solid card still belongs to the app it came from.
  let solidFill: NSColor
  /// What the card casts: black for a shadow, the accent colour for a glow.
  let glow: NSColor
  let glowRadius: CGFloat
  let shadowOpacity: Float

  /// Theme and accent from the settings; "system" for either follows macOS at the moment the card is made.
  init(icon: NSImage?) {
    let settings = Settings.shared
    let surface = settings.surface
    switch settings.theme {
    case .light: isDark = false
    case .dark: isDark = true
    case .system: isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
    let accent = (settings.accent.color ?? NSColor.controlAccentColor).usingColorSpace(.deviceRGB) ?? NSColor.systemBlue
    let h = accent.hueComponent
    // 모노 is the one theme that answers "which app is this?" with nothing: colour is taken out
    // everywhere, so the hue below is only kept alive to keep the arithmetic in one shape.
    let colourful = surface != .mono
    let sat: (CGFloat) -> CGFloat = { colourful ? $0 : 0 }
    tint = colourful ? accent : NSColor(calibratedWhite: isDark ? 0.72 : 0.45, alpha: 1)
    if isDark {
      warm = NSColor(calibratedHue: Palette.wrap(h + 0.09), saturation: sat(0.85), brightness: 0.95, alpha: 1)
      cool = NSColor(calibratedHue: Palette.wrap(h - 0.14), saturation: sat(0.9), brightness: 0.9, alpha: 1)
      text = .labelColor
      textSecondary = .secondaryLabelColor
      textTertiary = .secondaryLabelColor
      rim = Palette.rimColours(surface: surface, edge: tint, dark: true)
      pillFill = NSColor.white.withAlphaComponent(0.14)
      pillHover = NSColor.white.withAlphaComponent(0.26)
      pillPressed = NSColor.white.withAlphaComponent(0.36)
      pillBorder = NSColor.white.withAlphaComponent(0.2)
      sweep = NSColor.white.withAlphaComponent(0.28)
      blobAlpha = 0.38
      wash = NSColor(calibratedHue: h, saturation: sat(0.5), brightness: 0.2, alpha: 0.28)
      // Neon sits on near-black so the edge light has something to read against.
      solidFill = surface == .neon
        ? NSColor(calibratedHue: h, saturation: sat(0.35), brightness: 0.09, alpha: 1)
        : NSColor(calibratedHue: h, saturation: sat(0.16), brightness: 0.17, alpha: 1)
      shadowOpacity = surface == .neon ? 0.9 : 0.55
      glow = surface == .neon ? accent : .black
      glowRadius = surface == .neon ? 38 : 24
    } else {
      warm = NSColor(calibratedHue: Palette.wrap(h + 0.09), saturation: sat(0.5), brightness: 1, alpha: 1)
      cool = NSColor(calibratedHue: Palette.wrap(h - 0.14), saturation: sat(0.55), brightness: 1, alpha: 1)
      let ink = NSColor(calibratedHue: h, saturation: 0.55, brightness: 0.2, alpha: 1)
      text = .labelColor
      textSecondary = .secondaryLabelColor
      textTertiary = .secondaryLabelColor
      rim = Palette.rimColours(surface: surface, edge: tint, dark: false, ink: ink)
      pillFill = NSColor.white.withAlphaComponent(0.6)
      pillHover = NSColor.white.withAlphaComponent(0.85)
      pillPressed = NSColor.white.withAlphaComponent(1)
      pillBorder = ink.withAlphaComponent(0.12)
      sweep = NSColor.white.withAlphaComponent(0.55)
      blobAlpha = 0.22
      wash = NSColor(calibratedHue: h, saturation: sat(0.12), brightness: 1, alpha: 0.4)
      solidFill = surface == .neon
        ? NSColor(calibratedHue: h, saturation: sat(0.10), brightness: 0.97, alpha: 1)
        : NSColor(calibratedHue: h, saturation: sat(0.05), brightness: 0.99, alpha: 1)
      shadowOpacity = surface == .neon ? 0.45 : 0.22
      glow = surface == .neon ? accent : .black
      glowRadius = surface == .neon ? 34 : 24
    }
  }

  /// The hairline border: brighter at the top, quieter at the bottom. Neon lights it with the accent
  /// colour; the rest keep the plain white or ink edge the material expects.
  static func rimColours(surface: Surface, edge: NSColor, dark: Bool, ink: NSColor? = nil) -> [NSColor] {
    if surface == .neon {
      return [edge.withAlphaComponent(dark ? 0.95 : 0.9), edge.withAlphaComponent(dark ? 0.4 : 0.35),
              edge.withAlphaComponent(dark ? 0.7 : 0.6)]
    }
    if dark {
      return [NSColor.white.withAlphaComponent(0.42), NSColor.white.withAlphaComponent(0.16),
              NSColor.white.withAlphaComponent(0.1)]
    }
    let ink = ink ?? NSColor(calibratedWhite: 0.2, alpha: 1)
    return [NSColor.white.withAlphaComponent(1), ink.withAlphaComponent(0.1), ink.withAlphaComponent(0.16)]
  }

  private static func wrap(_ h: CGFloat) -> CGFloat { h < 0 ? h + 1 : (h > 1 ? h - 1 : h) }
}

// MARK: - Sheen

/// Layer-hosting overlay above the glass: nothing but a one-off light sweep on arrival.
/// The glass itself is native, so the background shows through untouched.
private final class Sheen: NSView {
  private let sweep = CAGradientLayer()
  private let rim = CAShapeLayer()
  private let rimGradient = CAGradientLayer()

  init(palette: Palette) {
    super.init(frame: .zero)
    let host = CALayer()
    host.masksToBounds = true
    host.cornerRadius = Style.corner
    host.cornerCurve = .continuous
    layer = host
    wantsLayer = true
    sweep.colors = [palette.sweep.withAlphaComponent(0).cgColor, palette.sweep.cgColor,
                    palette.sweep.withAlphaComponent(0).cgColor]
    sweep.locations = [0, 0.5, 1]
    sweep.startPoint = CGPoint(x: 0, y: 0.5)
    sweep.endPoint = CGPoint(x: 1, y: 0.5)
    sweep.opacity = 0
    sweep.transform = CATransform3DMakeRotation(-0.35, 0, 0, 1)
    host.addSublayer(sweep)

    // Hairline border: brighter at the top edge, quieter at the bottom.
    rimGradient.colors = palette.rim.map(\.cgColor)
    rimGradient.startPoint = CGPoint(x: 0.5, y: 1)
    rimGradient.endPoint = CGPoint(x: 0.5, y: 0)
    rim.fillColor = nil
    rim.strokeColor = NSColor.white.cgColor
    rim.lineWidth = 1
    rimGradient.mask = rim
    host.addSublayer(rimGradient)
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()
    let b = bounds
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer?.frame = b
    rimGradient.frame = b
    rim.frame = b
    rim.path = CGPath(roundedRect: b.insetBy(dx: 0.5, dy: 0.5), cornerWidth: Style.corner - 0.5,
                      cornerHeight: Style.corner - 0.5, transform: nil)
    sweep.bounds = CGRect(x: 0, y: 0, width: b.width * 0.35, height: b.height * 1.6)
    sweep.position = CGPoint(x: -b.width * 0.2, y: b.height / 2)
    CATransaction.commit()
  }

  func burst() {
    let b = bounds
    let slide = CABasicAnimation(keyPath: "position.x")
    slide.fromValue = -b.width * 0.2
    slide.toValue = b.width * 1.2
    slide.duration = 0.8
    slide.beginTime = CACurrentMediaTime() + 0.12
    slide.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.1, 0.3, 1)
    slide.fillMode = .backwards
    sweep.add(slide, forKey: "sweep")
    let fade = CAKeyframeAnimation(keyPath: "opacity")
    fade.values = [0, 1, 1, 0]
    fade.keyTimes = [0, 0.15, 0.75, 1]
    fade.duration = 0.9
    fade.beginTime = CACurrentMediaTime() + 0.12
    sweep.add(fade, forKey: "sweepFade")
  }
}

// MARK: - Group

/// Everything one app has shown while its card is up. Newest notice first.
final class NoticeGroup {
  let app: String
  let icon: NSImage?
  /// Relayed from the mirrored iPhone; kept so a phone card never merges with the Mac app's card.
  let fromIPhone: Bool
  private(set) var notices: [Notice]

  init(_ notice: Notice) {
    app = notice.app
    icon = notice.icon
    fromIPhone = notice.fromIPhone
    notices = [notice]
  }

  var latest: Notice { notices[0] }
  var isAlert: Bool { notices.contains { $0.isAlert } }
  var isPinned: Bool { notices.contains { $0.pinned } }
  var isEmpty: Bool { notices.isEmpty }

  func add(_ notice: Notice) { notices.insert(notice, at: 0) }

  /// Pushes every arrival forward, for time that should not have counted — the pointer resting on
  /// the card while someone reads it.
  func shiftArrival(by seconds: TimeInterval) {
    for i in notices.indices { notices[i].arrived = notices[i].arrived.addingTimeInterval(seconds) }
  }

  /// Drops notices that have had their time. `keep` spares the ones whose banner is still there —
  /// a call that is still ringing, an alert nobody has answered — so only the spent ones go.
  @discardableResult
  func prune(after seconds: TimeInterval, keep: (Notice) -> Bool) -> Bool {
    let before = notices.count
    let now = Date()
    notices.removeAll { now.timeIntervalSince($0.arrived) > seconds && !keep($0) }
    return notices.count != before
  }

  /// Drops a notice whose system banner is gone; returns true when something was removed.
  @discardableResult
  func remove(key: String) -> Bool {
    let before = notices.count
    notices.removeAll { $0.key == key }
    return notices.count != before
  }
}

// MARK: - Card

/// Glass card for one app's group. Pops in at the centre, updates in place, pops out.
final class CardPanel: NSPanel {
  let group: NoticeGroup
  var onActivate: ((Notice) -> Void)?
  var onAction: ((Notice, AXAction) -> Void)?
  var onShowImage: ((Notice) -> Void)?
  var onClose: ((NoticeGroup) -> Void)?
  var onDismiss: (() -> Void)?
  var onDrag: ((CardPanel) -> Void)?
  var onDragEnd: ((CardPanel) -> Void)?
  private var presentedAt = Date.distantPast
  private var dragStart: NSPoint?
  private var dragOrigin = NSPoint.zero
  private(set) var isDragging = false
  private var isHovered = false
  private var dismissWhenMouseLeaves = false
  private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  private let root = NSView()
  private let glassHost = NSView()
  private var contentHost = NSView()
  private var sheen: Sheen!
  private var content: NSView?
  private var iconView: NSImageView?
  private var closeButton: NSButton?
  private var ring: CountdownRing?
  private var buttonActions: [AXAction] = []
  /// Buttons belonging to older notifications on this card, by the tag their pill carries.
  private var historyActions: [Int: (Notice, AXAction)] = [:]
  private let historyTagSeed = 100
  /// A card opens folded at four lines. Scrolling on it — the movement you would make to read on —
  /// opens the rest, so nothing has to be aimed at.
  private var expanded = false
  private var folded = false
  /// A notification's buttons are pressable only while its own banner exists. macOS keeps a couple
  /// alive and destroys the rest, so this is asked per notification, not per card: on a card holding
  /// several, one line can still act while another cannot.
  private func isLive(_ notice: Notice) -> Bool { notice.element?.role != nil }
  private var auroraBlobs: [CAGradientLayer] = []
  private let palette: Palette
  private var dismissWork: DispatchWorkItem?
  private var pruneTimer: Timer?
  /// The dots on screen, with the notice each one is counting for: hovering has to stop them all
  /// together and start them again where they stopped.
  private var dots: [(dot: CountdownDot, key: String)] = []
  private var hoverStarted: Date?
  private(set) var isClosing = false
  private(set) var cardHeight: CGFloat = 0
  /// The card changed height on its own; the stack has to make room.
  var onResize: (() -> Void)?

  init(group: NoticeGroup) {
    self.group = group
    self.palette = Palette(icon: group.icon)
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: Style.width + Style.margin * 2, height: 100),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = .screenSaver
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    // The card's own theme: the glass material and label colours resolve against this, not the system's.
    appearance = NSAppearance(named: palette.isDark ? .darkAqua : .aqua)
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isReleasedWhenClosed = false
    animationBehavior = .none
    buildShell()
    rebuildContent()
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  // MARK: shell (glass + backdrop), built once

  private func buildShell() {
    root.wantsLayer = true
    contentView = root

    let shadow = NSView()
    shadow.wantsLayer = true
    shadow.layer?.shadowColor = palette.glow.cgColor
    shadow.layer?.shadowOpacity = palette.shadowOpacity
    shadow.layer?.shadowRadius = palette.glowRadius
    shadow.layer?.shadowOffset = CGSize(width: 0, height: -10)
    shadow.layer?.cornerRadius = Style.corner
    shadow.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.001).cgColor
    shadow.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(shadow)

    // Everything inside is clipped to the card shape, so no effect spills outside the card.
    glassHost.wantsLayer = true
    glassHost.layer?.cornerRadius = Style.corner
    glassHost.layer?.cornerCurve = .continuous
    glassHost.layer?.masksToBounds = true
    glassHost.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(glassHost)

    // Native Liquid Glass on macOS 26; frosted material before that. Content lives inside the
    // glass's contentView so the system renders text and refraction together.
    let surface = Settings.shared.surface
    let glass: NSView
    if !surface.isTranslucent {
      // Nothing shows through: a plain card, the fastest to draw and the easiest to read over a
      // busy desktop. Neon uses it too — its light has to fall on something solid to read as light.
      // The sheen stays either way: a highlight on the surface, not a hole in it.
      let v = NSView()
      v.wantsLayer = true
      v.layer?.backgroundColor = palette.solidFill.cgColor
      v.layer?.cornerRadius = Style.corner
      v.layer?.cornerCurve = .continuous
      v.layer?.masksToBounds = true
      contentHost = v
      glass = v
    } else if #available(macOS 26.0, *) {
      let g = NSGlassEffectView()
      g.cornerRadius = Style.corner
      g.style = .regular
      // Mono leans on the glass itself with a colourless wash; aurora keeps its tint quiet so the
      // clouds carry the colour; glass sits in between.
      let strength: CGFloat = surface == .mono ? 0.16 : (surface == .aurora ? 0.04 : 0.07)
      g.tintColor = palette.tint.withAlphaComponent(palette.isDark ? strength : strength + 0.02)
      let host = NSView()
      g.contentView = host
      contentHost = host
      glass = g
    } else {
      let v = NSVisualEffectView()
      v.material = palette.isDark ? .hudWindow : .popover
      v.blendingMode = .behindWindow
      v.state = .active
      v.wantsLayer = true
      v.layer?.cornerRadius = Style.corner
      v.layer?.cornerCurve = .continuous
      v.layer?.masksToBounds = true
      contentHost = v
      glass = v
    }
    glass.translatesAutoresizingMaskIntoConstraints = false
    glassHost.addSubview(glass)

    // The glass's content view has no layer of its own until asked, and the clouds live in it.
    contentHost.wantsLayer = true
    if surface == .aurora, let host = contentHost.layer {
      // Two soft clouds of the app's own warm and cool tones, sitting under everything the card
      // draws. Placed off-centre and off-edge so the card never looks like a symmetrical gradient.
      for (colour, centre) in [(palette.warm, CGPoint(x: 0.18, y: 0.9)), (palette.cool, CGPoint(x: 0.92, y: 0.05))] {
        let blob = CAGradientLayer()
        blob.type = .radial
        blob.colors = [colour.withAlphaComponent(palette.blobAlpha).cgColor,
                       colour.withAlphaComponent(0).cgColor]
        blob.locations = [0, 1]
        blob.startPoint = centre
        blob.endPoint = CGPoint(x: centre.x + 0.85, y: centre.y + 0.85)
        blob.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        host.insertSublayer(blob, at: 0)
        auroraBlobs.append(blob)
      }
    }

    sheen = Sheen(palette: palette)
    sheen.translatesAutoresizingMaskIntoConstraints = false
    glassHost.addSubview(sheen)

    NSLayoutConstraint.activate([
      glassHost.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: Style.margin),
      glassHost.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -Style.margin),
      glassHost.topAnchor.constraint(equalTo: root.topAnchor, constant: Style.margin),
      glassHost.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -Style.margin),
      shadow.leadingAnchor.constraint(equalTo: glassHost.leadingAnchor),
      shadow.trailingAnchor.constraint(equalTo: glassHost.trailingAnchor),
      shadow.topAnchor.constraint(equalTo: glassHost.topAnchor),
      shadow.bottomAnchor.constraint(equalTo: glassHost.bottomAnchor),
      glass.leadingAnchor.constraint(equalTo: glassHost.leadingAnchor),
      glass.trailingAnchor.constraint(equalTo: glassHost.trailingAnchor),
      glass.topAnchor.constraint(equalTo: glassHost.topAnchor),
      glass.bottomAnchor.constraint(equalTo: glassHost.bottomAnchor),
      sheen.leadingAnchor.constraint(equalTo: glassHost.leadingAnchor),
      sheen.trailingAnchor.constraint(equalTo: glassHost.trailingAnchor),
      sheen.topAnchor.constraint(equalTo: glassHost.topAnchor),
      sheen.bottomAnchor.constraint(equalTo: glassHost.bottomAnchor),
    ])

    let click = NSClickGestureRecognizer(target: self, action: #selector(bodyClicked))
    click.delegate = self
    glassHost.addGestureRecognizer(click)
    let tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
    glassHost.addTrackingArea(tracking)
  }

  // MARK: content, rebuilt whenever the group changes

  /// Lays out the newest notice big, older ones as a short list, and returns the new card height.
  @discardableResult
  func rebuildContent() -> CGFloat {
    // Cleared before anything is built: the marks and buttons registered below belong to this pass.
    historyActions.removeAll()
    dots.removeAll()
    content?.removeFromSuperview()
    installCorner()
    let notice = group.latest
    let textShadow = NSShadow()
    textShadow.shadowColor = NSColor.clear
    textShadow.shadowBlurRadius = 5
    textShadow.shadowOffset = NSSize(width: 0, height: -1)

    let icon = NSImageView()
    icon.image = group.icon ?? AppIcons.macImage
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.contentTintColor = palette.text
    icon.wantsLayer = true
    icon.layer?.shadowColor = NSColor.black.cgColor
    icon.layer?.shadowOpacity = palette.isDark ? 0.35 : 0.18
    icon.layer?.shadowRadius = 8
    icon.layer?.shadowOffset = CGSize(width: 0, height: -3)
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.widthAnchor.constraint(equalToConstant: Style.iconSize).isActive = true
    icon.heightAnchor.constraint(equalToConstant: Style.iconSize).isActive = true
    iconView = icon

    // 18 keeps the first row clear of the close button and its ring in the corner.
    let textWidth = Style.width - Style.padding * 2 - Style.iconSize - 16 - 18

    let appLabel = NSTextField(labelWithString: "")
    let appText = NSMutableAttributedString(string: group.app.uppercased())
    appText.addAttributes([
      .kern: 1.3, .font: NSFont.systemFont(ofSize: 11 * Style.scale, weight: .semibold),
      .foregroundColor: palette.textTertiary,
    ], range: NSRange(location: 0, length: appText.length))
    appLabel.attributedStringValue = appText
    appLabel.lineBreakMode = .byTruncatingTail
    appLabel.maximumNumberOfLines = 1
    let header = NSStackView(views: [countdownDot(for: notice), appLabel])
    header.orientation = .horizontal
    header.spacing = 7
    header.alignment = .centerY

    let titleFont = NSFont.systemFont(ofSize: 20 * Style.scale, weight: .bold)
    let titleText = NSMutableAttributedString(
      string: Self.clamped(notice.title, to: 2, attributes: [.font: titleFont], font: titleFont,
                           spacing: 0, width: textWidth),
      attributes: [.font: titleFont, .foregroundColor: palette.text])
    let title = NSTextField(wrappingLabelWithString: "")
    title.attributedStringValue = titleText
    title.font = titleFont
    title.textColor = palette.text
    title.shadow = textShadow
    title.maximumNumberOfLines = 2
    title.preferredMaxLayoutWidth = textWidth
    title.isSelectable = false
    title.isHidden = notice.title.isEmpty

    let subtitleFont = NSFont.systemFont(ofSize: 14.5 * Style.scale, weight: .semibold)
    let subtitle = NSTextField(wrappingLabelWithString:
      Self.clamped(notice.subtitle, to: 2, attributes: [.font: subtitleFont], font: subtitleFont,
                   spacing: 0, width: textWidth))
    subtitle.font = subtitleFont
    subtitle.textColor = palette.textSecondary
    subtitle.shadow = textShadow
    subtitle.maximumNumberOfLines = 2
    subtitle.preferredMaxLayoutWidth = textWidth
    subtitle.isSelectable = false
    subtitle.isHidden = notice.subtitle.isEmpty

    let body = NSTextField(wrappingLabelWithString: "")
    let para = NSMutableParagraphStyle()
    para.lineSpacing = 1.5
    // The label only ever wraps: a truncating mode makes AppKit lay the text out on a single line.
    // The cut and its ellipsis are put into the string before it gets here.
    para.lineBreakMode = .byWordWrapping
    let bodyFont = NSFont.systemFont(ofSize: 14.5 * Style.scale)
    let bodyAttributes: [NSAttributedString.Key: Any] = [
      .font: bodyFont, .foregroundColor: palette.textTertiary, .paragraphStyle: para]
    // Cut to four lines here rather than leaving it to the label: a text field asks for the height
    // of every line it holds, so the card would simply grow and nothing would ever be truncated.
    let bodyLines = expanded ? 40 : 4
    let shownBody = Self.clamped(notice.body, to: bodyLines, attributes: bodyAttributes, font: bodyFont,
                                 spacing: para.lineSpacing, width: textWidth)
    let bodyFolded = shownBody != notice.body
    body.attributedStringValue = NSAttributedString(string: shownBody, attributes: bodyAttributes)
    body.font = .systemFont(ofSize: 14.5 * Style.scale)
    body.textColor = palette.textTertiary
    body.shadow = textShadow
    body.maximumNumberOfLines = bodyLines
    body.preferredMaxLayoutWidth = textWidth
    body.isSelectable = false
    body.isHidden = notice.body.isEmpty

    // The banner's own buttons, minus its close action: the X in the corner already is that.
    // Pressing one hands the press back to the real banner, which is where the system draws
    // whatever the button opens (a reply field, a menu).
    buttonActions = isLive(notice)
      ? Array(notice.actions.filter { !$0.isClose && !$0.isExpand && !$0.isOpenApp }.prefix(3))
      : []
    let text = NSStackView(views: [header, title, subtitle, body])
    text.orientation = .vertical
    text.alignment = .leading
    text.spacing = 2
    text.setCustomSpacing(6, after: header)
    text.setCustomSpacing(3, after: title)
    text.translatesAutoresizingMaskIntoConstraints = false
    text.widthAnchor.constraint(equalToConstant: textWidth).isActive = true

    let row = NSStackView(views: [icon, text])
    row.orientation = .horizontal
    row.alignment = .top
    row.spacing = 16
    row.alignment = .top

    folded = bodyFolded
    // A picture came with this notification and the card cannot draw it. The button hands the
    // notification back to the system's banner, in the card's place, where the picture is drawn.
    var extras: [NSButton] = []
    if notice.hasImage, isLive(notice) {
      let photo = pill(T("사진"), tag: -1)
      photo.target = self
      photo.action = #selector(showImage)
      extras.append(photo)
    }

    // The latest notification's own buttons, directly under its text: they belong to it, not to the
    // history that follows.
    let innerWidth = Style.width - Style.padding * 2
    let column = NSStackView(views: [row])
    column.orientation = .vertical
    column.alignment = .leading
    column.spacing = 10
    if !buttonActions.isEmpty || !extras.isEmpty {
      // A spacer as wide as the icon and its gap, so the buttons start on the text's left edge.
      let indent = NSView()
      indent.translatesAutoresizingMaskIntoConstraints = false
      indent.widthAnchor.constraint(equalToConstant: Style.iconSize + 16).isActive = true
      indent.heightAnchor.constraint(equalToConstant: 1).isActive = true
      let pills = NSStackView(views: [indent] + buttonActions.enumerated().map { pill($1.label, tag: $0) } + extras)
      pills.orientation = .horizontal
      pills.alignment = .centerY
      pills.spacing = 8
      pills.setCustomSpacing(0, after: indent)
      column.addArrangedSubview(pills)
    }

    // Older notices from the same app, newest first.
    let history = Array(group.notices.dropFirst().prefix(Style.maxHistory))
    if !history.isEmpty {
      column.addArrangedSubview(divider(width: innerWidth))
      let historyStack = NSStackView(views: history.map { historyRow($0, width: innerWidth) })
      historyStack.orientation = .vertical
      historyStack.alignment = .leading
      historyStack.spacing = 5
      column.addArrangedSubview(historyStack)
      let more = group.notices.count - 1 - history.count
      if more > 0 {
        let rest = NSTextField(labelWithString: T("그리고 %d개 더", more))
        rest.font = .systemFont(ofSize: 12 * Style.scale, weight: .medium)
        rest.textColor = palette.textTertiary
        column.addArrangedSubview(rest)
      }
    }
    column.translatesAutoresizingMaskIntoConstraints = false
    contentHost.addSubview(column, positioned: .below, relativeTo: nil)

    NSLayoutConstraint.activate([
      column.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor, constant: Style.padding),
      column.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: Style.padding),
      column.trailingAnchor.constraint(lessThanOrEqualTo: contentHost.trailingAnchor, constant: -Style.padding),
    ])
    content = column

    root.layoutSubtreeIfNeeded()
    cardHeight = max(Style.iconSize + Style.padding * 2, column.fittingSize.height + Style.padding * 2)
    if !auroraBlobs.isEmpty {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      for blob in auroraBlobs { blob.frame = contentHost.bounds }
      CATransaction.commit()
    }
    return cardHeight
  }

  /// The close button and its countdown ring sit in the card corner, apart from the content layout:
  /// made once, kept through rebuilds, always above whatever the content lays out.
  private func installCorner() {
    if closeButton == nil {
      let mark = NSImage(systemSymbolName: "xmark", accessibilityDescription: T("닫기"))!
        .withSymbolConfiguration(.init(pointSize: 12, weight: .bold)) ?? NSImage()
      let close = CloseButton(image: mark, target: self, action: #selector(closeClicked))
      close.isBordered = false
      close.idleTint = palette.text.withAlphaComponent(0.62)
      close.hoverTint = palette.text
      close.contentTintColor = close.idleTint
      close.translatesAutoresizingMaskIntoConstraints = false
      let ring = CountdownRing(tint: palette.tint, track: palette.text.withAlphaComponent(0.1), glow: palette.isDark)
      // Catches presses anywhere on the card except the corner, so a drag works over text and icon alike;
      // it handles nothing itself and lets the events climb to the panel.
      let dragCatcher = DragCatcher()
      dragCatcher.translatesAutoresizingMaskIntoConstraints = false
      contentHost.addSubview(dragCatcher)
      contentHost.addSubview(ring)
      contentHost.addSubview(close)
      NSLayoutConstraint.activate([
        dragCatcher.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
        dragCatcher.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
        dragCatcher.topAnchor.constraint(equalTo: contentHost.topAnchor),
        dragCatcher.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
        close.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: 15),
        close.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor, constant: -15),
        close.widthAnchor.constraint(equalToConstant: 18),
        close.heightAnchor.constraint(equalToConstant: 18),
        ring.centerXAnchor.constraint(equalTo: close.centerXAnchor),
        ring.centerYAnchor.constraint(equalTo: close.centerYAnchor),
        ring.widthAnchor.constraint(equalToConstant: CountdownRing.size),
        ring.heightAnchor.constraint(equalToConstant: CountdownRing.size),
      ])
      closeButton = close
      self.ring = ring
    }
    // The countdown lives in the dot beside the app name, on every line. The corner keeps only the
    // close button.
    ring?.isHidden = true
  }

  private func divider(width: CGFloat) -> NSView {
    let v = NSView()
    v.wantsLayer = true
    v.layer?.backgroundColor = palette.text.withAlphaComponent(0.1).cgColor
    v.translatesAutoresizingMaskIntoConstraints = false
    v.heightAnchor.constraint(equalToConstant: 1).isActive = true
    v.widthAnchor.constraint(equalToConstant: width).isActive = true
    return v
  }

  /// The mark for one notification: a ring draining over the time that notification has left. The
  /// same token on the card's own line and on every line stacked under it, so one glance reads them
  /// all. A notice whose banner is still standing — a call still ringing — is not on a clock, and
  /// its ring stays full.
  private func countdownDot(for notice: Notice) -> NSView {
    let dot = CountdownDot(colour: palette.tint, diameter: Style.dotSize)
    let total = Style.showSeconds
    let elapsed = Date().timeIntervalSince(notice.arrived)
    // Not everything is on a clock. A pinned notice waits to be closed and a ringing call waits to
    // be answered: their dots stay full, because nothing is running out.
    guard !notice.pinned, !(notice.isAlert && isLive(notice)), total > 0 else { return dot }
    dots.append((dot, notice.key))
    guard elapsed < total else {
      // Its time is up and it is only still here because the pointer is: an empty dot, not a fresh one.
      dot.empty()
      return dot
    }
    dot.drain(from: CGFloat(elapsed / total), over: total - elapsed)
    if isHovered { dot.freeze() }
    return dot
  }


  private func historyRow(_ n: Notice, width: CGFloat) -> NSView {
    // Each line has its own clock now, so each line shows it. A notice whose banner is still
    // standing is not on a clock at all — a ringing call waits for an answer — and keeps its dot.
    let mark = countdownDot(for: n)

    let line = NSMutableAttributedString()
    line.append(NSAttributedString(string: n.title, attributes: [
      .font: NSFont.systemFont(ofSize: 12.5 * Style.scale, weight: .semibold), .foregroundColor: palette.textSecondary]))
    let tail = [n.subtitle, n.body].filter { !$0.isEmpty }.joined(separator: " · ")
    if !tail.isEmpty {
      line.append(NSAttributedString(string: "  " + tail, attributes: [
        .font: NSFont.systemFont(ofSize: 12.5 * Style.scale), .foregroundColor: palette.textTertiary]))
    }
    let label = NSTextField(labelWithString: "")
    label.attributedStringValue = line
    label.lineBreakMode = .byTruncatingTail
    label.maximumNumberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    label.widthAnchor.constraint(lessThanOrEqualToConstant: width - 14).isActive = true
    // The line gives way to the buttons rather than pushing them off the card.
    label.setContentCompressionResistancePriority(.init(1), for: .horizontal)

    // The buttons of an older notification, on the right of its line. Only the ones still pressable:
    // macOS keeps a couple of banners alive at a time and destroys the rest, and a button whose
    // banner is gone would do nothing.
    var views: [NSView] = [mark, label]
    if isLive(n) {
      let live = n.actions.filter { !$0.isClose && !$0.isExpand && !$0.isOpenApp }.prefix(2)
      if !live.isEmpty {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        views.append(spacer)
        for action in live {
          let tag = historyTagSeed + historyActions.count
          historyActions[tag] = (n, action)
          views.append(pill(action.label, tag: tag, small: true))
        }
      }
    }
    let row = NSStackView(views: views)
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 8
    row.translatesAutoresizingMaskIntoConstraints = false
    row.widthAnchor.constraint(equalToConstant: width).isActive = true
    return row
  }

  /// A rounded action button. The padding is measured, not spelled with spaces: the text is centred
  /// by the layout and the pill is exactly as wide as the text plus its inset, at any card size.
  /// The text as much of it as fits in `lines`, with an ellipsis where it was cut. Measured against
  /// the real font and width, so the cut lands on the last line that fits rather than a guessed count.
  private static func clamped(_ text: String, to lines: Int, attributes: [NSAttributedString.Key: Any],
                              font: NSFont, spacing: CGFloat, width: CGFloat) -> String {
    let limit = ceil(NSLayoutManager().defaultLineHeight(for: font) * CGFloat(lines)
                     + spacing * CGFloat(lines - 1)) + 1
    // Measured as wrapping text. Measuring with a truncating style answers with the height of one
    // line — it never wraps — and every text would look like it fits.
    var measured = attributes
    let wrapping = ((attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy()
                    as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
    wrapping.lineBreakMode = .byWordWrapping
    measured[.paragraphStyle] = wrapping
    func height(_ candidate: String) -> CGFloat {
      NSAttributedString(string: candidate, attributes: measured)
        .boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                      options: [.usesLineFragmentOrigin, .usesFontLeading]).height
    }
    logD("clamp \(lines)줄 폭=\(Int(width)) 글자=\(text.count) 높이=\(Int(height(text))) 한계=\(Int(limit))")
    guard height(text) > limit else { return text }
    let characters = Array(text)
    var low = 0, high = characters.count
    while low < high {
      let mid = (low + high + 1) / 2
      if height(String(characters[0..<mid]) + "…") <= limit { low = mid } else { high = mid - 1 }
    }
    let kept = String(characters[0..<low]).trimmingCharacters(in: .whitespacesAndNewlines)
    logD("clamp 잘림 \(text.count) → \(kept.count)")
    return kept.isEmpty ? text : kept + "…"
  }

  private func pill(_ label: String, tag: Int, small: Bool = false) -> NSButton {
    let title = NSAttributedString(string: label, attributes: [
      .foregroundColor: small ? palette.textSecondary : palette.text,
      .font: NSFont.systemFont(ofSize: (small ? 11 : 13) * Style.scale, weight: .semibold),
    ])
    let height = (small ? 20 : 28) * Style.scale
    let b = PillButton(title: "", target: self, action: #selector(actionClicked(_:)))
    b.tag = tag
    b.isBordered = false
    b.attributedTitle = title
    b.fill = palette.pillFill
    b.hoverFill = palette.pillHover
    b.pressedFill = palette.pillPressed
    b.alignment = .center
    b.imagePosition = .noImage
    b.wantsLayer = true
    b.layer?.backgroundColor = palette.pillFill.cgColor
    b.layer?.borderColor = palette.pillBorder.cgColor
    b.layer?.borderWidth = 1
    b.layer?.cornerRadius = height / 2
    b.layer?.cornerCurve = .continuous
    b.translatesAutoresizingMaskIntoConstraints = false
    b.heightAnchor.constraint(equalToConstant: height).isActive = true
    b.widthAnchor.constraint(equalToConstant: ceil(title.size().width) + height).isActive = true
    return b
  }

  // MARK: interaction

  /// Clicks in the first moments after appearing were meant for whatever was underneath.
  private var settled: Bool { Date().timeIntervalSince(presentedAt) > 0.4 }

  @objc private func bodyClicked() {
    guard settled else { return }
    onActivate?(group.latest)
    dismiss()
  }

  override func scrollWheel(with event: NSEvent) {
    guard folded, !expanded, abs(event.scrollingDeltaY) > 0.5 else { return }
    expand()
  }

  /// Unfolds the body. The countdown stops while it is open — a card that vanishes mid-sentence is
  /// worse than one that overstays — and moving the pointer off the card ends it as usual.
  private func expand() {
    guard !expanded else { return }
    expanded = true
    dismissWork?.cancel()
    ring?.freeze()
    _ = rebuildContent()
    onResize?()
  }

  @objc private func showImage() {
    onShowImage?(group.latest)
    dismiss()
  }

  @objc private func actionClicked(_ sender: NSButton) {
    // An older notification's button acts on that notification, and leaves the card standing:
    // the others on it are still worth reading.
    if let (notice, action) = historyActions[sender.tag] {
      onAction?(notice, action)
      _ = rebuildContent()
      onResize?()
      return
    }
    guard buttonActions.indices.contains(sender.tag) else { return }
    // Whatever the button opens, the real banner takes over from here.
    onAction?(group.latest, buttonActions[sender.tag])
    dismiss()
  }

  @objc private func closeClicked() {
    guard settled else { return }
    onClose?(group)
    dismiss()
  }

  override func mouseEntered(with event: NSEvent) {
    logD("card \(group.app): mouse in")
    isHovered = true
    hoverStarted = Date()
    dismissWork?.cancel()
    ring?.freeze()
    for (dot, _) in dots { dot.freeze() }
  }

  override func mouseExited(with event: NSEvent) {
    guard !isDragging else { return }
    logD("card \(group.app): mouse out")
    isHovered = false
    // The time spent reading is given back to every notice on the card, so the dots pick up where
    // they stopped and the pruning agrees with them.
    if let started = hoverStarted {
      group.shiftArrival(by: Date().timeIntervalSince(started))
      hoverStarted = nil
      let total = Style.showSeconds
      for (dot, key) in dots {
        guard let notice = group.notices.first(where: { $0.key == key }) else { continue }
        let left = total - Date().timeIntervalSince(notice.arrived)
        if left > 0 { dot.drain(from: 1 - CGFloat(left / total), over: left) } else { dot.empty() }
      }
    }
    // The card leaves when its newest notice runs out, not on a fixed grace: the dot beside the app
    // name is showing that time, and the two have to end together. A brush past still gets a moment.
    let left = Style.showSeconds - Date().timeIntervalSince(group.latest.arrived)
    if dismissWhenMouseLeaves { startDismiss(after: 1.5) } else { scheduleAutoDismiss(after: max(1.5, left)) }
  }

  // MARK: drag

  /// The card without its transparent margin, in screen coordinates.
  private var cardRect: NSRect { frame.insetBy(dx: Style.margin, dy: Style.margin) }
  /// The same rect, for putting the real banner exactly where this card is.
  var cardFrame: NSRect { cardRect }

  override func mouseDown(with event: NSEvent) {
    dragStart = NSEvent.mouseLocation
    dragOrigin = frame.origin
    isDragging = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start = dragStart else { return }
    let now = NSEvent.mouseLocation
    let dx = now.x - start.x, dy = now.y - start.y
    if !isDragging {
      guard hypot(dx, dy) > 4 else { return }
      isDragging = true
      dismissWork?.cancel()
      ring?.freeze()
    }
    setFrameOrigin(NSPoint(x: dragOrigin.x + dx, y: dragOrigin.y + dy))
    onDrag?(self)
  }

  override func mouseUp(with event: NSEvent) {
    defer { dragStart = nil }
    guard isDragging else { return }
    isDragging = false
    onDragEnd?(self)
    if !cardRect.contains(NSEvent.mouseLocation) { mouseExited(with: event) }
  }

  /// The system banner behind this card is gone. A banner card lives by the user's duration setting
  /// instead; only a persistent alert follows the system's, unless the user is looking at it.
  func originalGone() {
    logD("card \(group.app): original gone, alert=\(group.isAlert)")
    guard group.isAlert, !group.isPinned else {
      // A card outlives its banner by the user's duration setting, but not its buttons: the rebuild
      // asks each line again whether its own banner is still there.
      if !buttonActions.isEmpty || !historyActions.isEmpty || group.latest.hasImage {
        _ = rebuildContent()
        onResize?()
      }
      return
    }
    if isHovered { dismissWhenMouseLeaves = true } else { dismiss() }
  }

  /// Every notice on the card ages out on its own once its time is up, unless its banner is still
  /// standing. Without this a single lingering alert would hold the whole stack on screen forever.
  private func startPruning() {
    pruneTimer?.invalidate()
    // Often enough that a line leaves as its dot empties, not a beat later.
    pruneTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] timer in
      guard let self else { timer.invalidate(); return }
      // Not while it is being read.
      guard !self.isHovered, !self.expanded else { return }
      // Pinned means pinned: it goes when it is closed, never because time passed. A notice whose
      // banner is still standing waits too — a call keeps ringing until someone answers.
      guard self.group.prune(after: Style.showSeconds,
                             keep: { $0.pinned || self.isLive($0) }) else { return }
      logD("card \(self.group.app): pruned, \(self.group.notices.count) left")
      if self.group.isEmpty {
        timer.invalidate()
        self.dismiss()
        return
      }
      _ = self.rebuildContent()
      self.onResize?()
    }
  }

  /// Banners follow the system banner's own lifetime; this timer is only the fallback.
  /// A persistent alert stays, exactly like the system's, until the user acts on it.
  func scheduleAutoDismiss(after seconds: TimeInterval = Style.showSeconds) {
    dismissWork?.cancel()
    // The card's clock belongs to its newest notice, not to the whole stack: one pinned alert
    // underneath used to stop the countdown for everything above it. Only a notice whose banner is
    // still standing — a call still ringing — waits instead of counting.
    guard !isHovered, !(group.latest.isAlert && isLive(group.latest)) else { return }
    startDismiss(after: seconds)
  }

  /// The countdown itself: the ring drains over `seconds`, then the card goes unless the pointer came back.
  private func startDismiss(after seconds: TimeInterval) {
    logD("card \(group.app): timer \(seconds)s")
    dismissWork?.cancel()
    ring?.drain(over: seconds)
    let work = DispatchWorkItem { [weak self] in
      guard let self, !self.isHovered else { return }
      // The newest notice running out is not the card running out: anything still waiting under it
      // — something pinned, a call still ringing — takes its place at the top instead.
      self.group.prune(after: Style.showSeconds, keep: { $0.pinned || self.isLive($0) })
      guard !self.group.isEmpty else {
        self.dismiss()
        return
      }
      _ = self.rebuildContent()
      self.onResize?()
      let left = Style.showSeconds - Date().timeIntervalSince(self.group.latest.arrived)
      if left > 0 { self.scheduleAutoDismiss(after: left) }
    }
    dismissWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
  }

  // MARK: animation

  /// Scale about the centre of the content, independent of AppKit's layer anchor handling.
  private func transform(scale: CGFloat, dy: CGFloat) -> CATransform3D {
    let cx = root.bounds.midX, cy = root.bounds.midY
    var t = CATransform3DMakeTranslation(cx, cy + dy, 0)
    t = CATransform3DScale(t, scale, scale, 1)
    return CATransform3DTranslate(t, -cx, -cy, 0)
  }

  func present(at frame: NSRect) {
    presentedAt = Date()
    startPruning()
    setFrame(frame, display: false)
    isHovered = cardRect.contains(NSEvent.mouseLocation)
    root.layoutSubtreeIfNeeded()
    sheen.layout()
    guard let layer = root.layer else { return }
    if reduceMotion {
      alphaValue = 0
      orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.2
        animator().alphaValue = 1
      }
      scheduleAutoDismiss()
      return
    }
    let from = transform(scale: 0.6, dy: -20)
    layer.sublayerTransform = from
    alphaValue = 0
    orderFrontRegardless()

    let spring = CASpringAnimation(keyPath: "sublayerTransform")
    spring.fromValue = NSValue(caTransform3D: from)
    spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
    spring.stiffness = 260
    spring.damping = 16
    spring.initialVelocity = 6
    spring.duration = spring.settlingDuration
    layer.add(spring, forKey: "pop")
    layer.sublayerTransform = CATransform3DIdentity

    if let iconLayer = iconView?.layer {
      let bounce = CASpringAnimation(keyPath: "transform.scale")
      bounce.fromValue = 0.3
      bounce.toValue = 1.0
      bounce.mass = 0.8
      bounce.stiffness = 300
      bounce.damping = 11
      bounce.initialVelocity = 8
      bounce.beginTime = CACurrentMediaTime() + 0.08
      bounce.fillMode = .backwards
      bounce.duration = bounce.settlingDuration
      iconLayer.add(bounce, forKey: "land")
    }

    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.14
      ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
      animator().alphaValue = 1
    }
    sheen.burst()
    scheduleAutoDismiss()
  }

  /// Called after the group gained a notice: content is rebuilt, the card nudges and the timer restarts.
  func bump() {
    logD("card \(group.app): bump, hovered=\(isHovered)")
    ring?.refill()
    scheduleAutoDismiss()
    guard !reduceMotion, let layer = root.layer else { return }
    let nudge = CAKeyframeAnimation(keyPath: "sublayerTransform")
    nudge.values = [CATransform3DIdentity, transform(scale: 1.035, dy: 0), CATransform3DIdentity]
      .map { NSValue(caTransform3D: $0) }
    nudge.keyTimes = [0, 0.4, 1]
    nudge.duration = 0.32
    nudge.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeInEaseOut)]
    layer.add(nudge, forKey: "bump")
    sheen.burst()
  }

  func move(to frame: NSRect) {
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.3
      ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1)
      animator().setFrame(frame, display: true)
    }
  }

  func dismiss() {
    guard !isClosing else { return }
    logD("card \(group.app): dismiss")
    isClosing = true
    dismissWork?.cancel()
    pruneTimer?.invalidate()
    guard !reduceMotion, let layer = root.layer else {
      NSAnimationContext.runAnimationGroup({ ctx in
        ctx.duration = 0.15
        animator().alphaValue = 0
      }, completionHandler: { [weak self] in
        self?.orderOut(nil)
        self?.onDismiss?()
      })
      return
    }
    let to = transform(scale: 0.8, dy: 22)
    let shrink = CABasicAnimation(keyPath: "sublayerTransform")
    shrink.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
    shrink.toValue = NSValue(caTransform3D: to)
    shrink.duration = 0.24
    shrink.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
    layer.add(shrink, forKey: "shrink")
    layer.sublayerTransform = to
    NSAnimationContext.runAnimationGroup({ ctx in
      ctx.duration = 0.22
      ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
      animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      guard let self else { return }
      self.orderOut(nil)
      self.onDismiss?()
    })
  }
}

extension CardPanel: NSGestureRecognizerDelegate {
  func gestureRecognizer(_ g: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
    // hitTest takes a point in the receiver's superview coordinates; for the content view that is the window.
    return !(root.hitTest(event.locationInWindow) is NSButton)
  }
}

// MARK: - Countdown ring

/// Time left before the card goes, as an arc around the close button. It only reads: it drains
/// clockwise from full, holds while the pointer is on the card, and refills when a new notice lands.
/// A notification's mark: a filled dot that empties like a clock face over the time that
/// notification has left. Drawn as one thick stroke on a small circle, so sweeping the stroke away
/// takes the fill with it from the centre out.
private final class CountdownDot: NSView {
  private let pie = CAShapeLayer()
  private let diameter: CGFloat

  init(colour: NSColor, diameter: CGFloat) {
    self.diameter = diameter
    super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
    wantsLayer = true
    translatesAutoresizingMaskIntoConstraints = false
    pie.fillColor = nil
    pie.strokeColor = colour.cgColor
    pie.lineWidth = diameter / 2
    pie.shadowColor = colour.cgColor
    pie.shadowOpacity = 0.7
    pie.shadowRadius = 3
    pie.shadowOffset = .zero
    layer?.addSublayer(pie)

    widthAnchor.constraint(equalToConstant: diameter).isActive = true
    heightAnchor.constraint(equalToConstant: diameter).isActive = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  /// Drawn from the view's own middle every time it is laid out, so the dot sits dead centre in the
  /// square it is given whatever that square turns out to be.
  override func layout() {
    super.layout()
    let side = min(bounds.width, bounds.height)
    let centre = NSPoint(x: bounds.midX, y: bounds.midY)
    let path = NSBezierPath()
    path.appendArc(withCenter: centre, radius: side / 4, startAngle: 90, endAngle: -270, clockwise: true)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    pie.frame = bounds
    pie.path = path.cgPath
    pie.lineWidth = side / 2
    CATransaction.commit()
  }

  /// How much of the dot is spent right now: the running animation's own value while it runs,
  /// otherwise the model value a freeze or a fill has just set.
  var spent: CGFloat {
    guard pie.animation(forKey: "drain") != nil, let shown = pie.presentation() else { return pie.strokeStart }
    return shown.strokeStart
  }

  /// Stops the clock where it stands. The card does the same with its own dismissal while the
  /// pointer is on it, and the two have to agree.
  func freeze() {
    let now = spent
    pie.removeAnimation(forKey: "drain")
    pie.strokeStart = now
  }

  /// Empty: the time is up but the line is still on screen, waiting for the pointer to leave.
  func empty() {
    pie.removeAnimation(forKey: "drain")
    pie.strokeStart = 1
  }

  /// Picks up where the clock already is: a notice that has been waiting shows a dot already
  /// part-spent rather than starting over.
  func drain(from start: CGFloat, over seconds: TimeInterval) {
    pie.removeAnimation(forKey: "drain")
    pie.strokeStart = start
    let a = CABasicAnimation(keyPath: "strokeStart")
    a.fromValue = start
    a.toValue = 1
    a.duration = max(0.01, seconds)
    a.timingFunction = CAMediaTimingFunction(name: .linear)
    a.fillMode = .forwards
    a.isRemovedOnCompletion = false
    pie.add(a, forKey: "drain")
  }
}

/// The card's close button: clear enough to find without hunting, brighter under the pointer.
private final class CloseButton: NSButton {
  var idleTint: NSColor = .labelColor
  var hoverTint: NSColor = .labelColor
  private var tracking: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let tracking { removeTrackingArea(tracking) }
    let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
    addTrackingArea(area)
    tracking = area
  }

  override func mouseEntered(with event: NSEvent) { contentTintColor = hoverTint }
  override func mouseExited(with event: NSEvent) { contentTintColor = idleTint }
}

/// An action pill that answers the pointer: brighter under it, brighter still while held.
private final class PillButton: NSButton {
  var fill: NSColor = .clear { didSet { paint(fill) } }
  var hoverFill: NSColor = .clear
  var pressedFill: NSColor = .clear
  private var hovering = false
  private var tracking: NSTrackingArea?

  private func paint(_ color: NSColor) {
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.12)
    layer?.backgroundColor = color.cgColor
    CATransaction.commit()
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let tracking { removeTrackingArea(tracking) }
    let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
    addTrackingArea(area)
    tracking = area
  }

  override func mouseEntered(with event: NSEvent) {
    hovering = true
    paint(hoverFill)
  }

  override func mouseExited(with event: NSEvent) {
    hovering = false
    paint(fill)
  }

  override func mouseDown(with event: NSEvent) {
    paint(pressedFill)
    super.mouseDown(with: event)
    paint(hovering ? hoverFill : fill)
  }
}

/// The full-card drag surface. It sits above the content so a drag starts anywhere, which would
/// also swallow clicks meant for the action buttons underneath: those get their own hit back.
private final class DragCatcher: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    for sibling in superview?.subviews ?? [] where sibling !== self {
      if let hit = sibling.hitTest(point), hit is NSButton { return hit }
    }
    return super.hitTest(point)
  }
}

final class CountdownRing: NSView {
  static let size: CGFloat = 30
  private let arc = CAShapeLayer()

  init(tint: NSColor, track: NSColor, glow: Bool, diameter: CGFloat = CountdownRing.size) {
    super.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
    wantsLayer = true
    translatesAutoresizingMaskIntoConstraints = false
    let r = diameter / 2
    let path = NSBezierPath()
    path.appendArc(withCenter: NSPoint(x: r, y: r), radius: r - 2, startAngle: 90, endAngle: -270, clockwise: true)
    let trackLayer = CAShapeLayer()
    for (shape, color) in [(trackLayer, track), (arc, tint)] {
      shape.path = path.cgPath
      shape.fillColor = nil
      shape.strokeColor = color.cgColor
      shape.lineWidth = diameter < 20 ? 1.6 : 2.4
      shape.lineCap = .round
      shape.frame = bounds
      layer?.addSublayer(shape)
    }
    if glow {
      arc.shadowColor = tint.cgColor
      arc.shadowOpacity = 0.6
      arc.shadowRadius = 4
      arc.shadowOffset = .zero
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  /// Purely visual: clicks fall through to whatever is underneath.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  /// Where the drained edge is right now, 0 (full) … 1 (empty). While a drain is running that is what
  /// is on screen; otherwise the model value, which a refill or freeze has just set.
  private var drained: CGFloat {
    guard arc.animation(forKey: "drain") != nil, let shown = arc.presentation() else { return arc.strokeStart }
    return shown.strokeStart
  }

  /// Picks up from where the clock already is: a notice that has been on the card for a while shows
  /// the ring already part-spent rather than starting over.
  func drain(from start: CGFloat, over seconds: TimeInterval) {
    set(strokeStart: start)
    let a = CABasicAnimation(keyPath: "strokeStart")
    a.fromValue = start
    a.toValue = 1
    a.duration = max(0.01, seconds)
    a.timingFunction = CAMediaTimingFunction(name: .linear)
    a.fillMode = .forwards
    a.isRemovedOnCompletion = false
    arc.add(a, forKey: "drain")
  }

  func drain(over seconds: TimeInterval) {
    let from = drained
    set(strokeStart: 1)
    let a = CABasicAnimation(keyPath: "strokeStart")
    a.fromValue = from
    a.toValue = 1
    a.duration = seconds
    a.timingFunction = CAMediaTimingFunction(name: .linear)
    arc.add(a, forKey: "drain")
  }

  func freeze() { set(strokeStart: drained) }
  func refill() { set(strokeStart: 0) }

  private func set(strokeStart: CGFloat) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    arc.removeAllAnimations()
    arc.strokeStart = strokeStart
    CATransaction.commit()
  }
}

// MARK: - Manager

/// Handlers the app supplies for what a card can do with the original system notification.
struct CardHandlers {
  let activate: (Notice) -> Void
  let action: (Notice, AXAction) -> Void
  /// The card was asked to hand this notification back to the system so its picture can be seen.
  let showImage: (Notice) -> Void
  let close: (NoticeGroup) -> Void
}

/// One card per app, the stack anchored where the settings say, on the chosen display.
final class CardManager {
  private var cards: [CardPanel] = []
  private let handlers: CardHandlers
  private let settings = Settings.shared

  /// The display to place the stack on: the user's explicit choice, else the one the newest card's
  /// notification appeared on, else the primary. Following the notification keeps "가운데" truly centred
  /// on the display the banner used, regardless of arrangement or resolution.
  private var currentScreen: NSScreen {
    if settings.displayID != 0 { return settings.screen }
    if let id = cards.first?.group.latest.screenNumber, id != 0,
       let match = NSScreen.screens.first(where: { Settings.id(of: $0) == id }) { return match }
    return Settings.primaryScreen
  }

  init(handlers: CardHandlers) { self.handlers = handlers }

  func add(_ notice: Notice) {
    // Group only same app AND same source: a message mirrored from the iPhone is its own card, separate
    // from the same app running on this Mac. A card on its way out cannot take the notice either.
    if !notice.app.isEmpty, let existing = cards.first(where: {
      $0.group.app == notice.app && $0.group.fromIPhone == notice.fromIPhone && !$0.isClosing
    }) {
      existing.group.add(notice)
      existing.rebuildContent()
      cards.removeAll { $0 === existing }
      cards.insert(existing, at: 0)
      layout()
      existing.bump()
      return
    }
    let card = CardPanel(group: NoticeGroup(notice))
    card.onActivate = handlers.activate
    card.onAction = handlers.action
    card.onShowImage = handlers.showImage
    card.onClose = handlers.close
    card.onDismiss = { [weak self, weak card] in
      guard let self, let card else { return }
      self.cards.removeAll { $0 === card }
      self.layout()
    }
    card.onResize = { [weak self] in self?.layout() }
    card.onDrag = { [weak self] dragged in self?.follow(dragged) }
    card.onDragEnd = { [weak self] dragged in self?.dragEnded(dragged) }
    cards.insert(card, at: 0)
    while cards.count > Style.maxGroups, let oldest = cards.last {
      cards.removeLast()
      oldest.dismiss()
    }
    let frames = targetFrames()
    for (c, f) in zip(cards, frames) where c !== card { c.move(to: f) }
    card.present(at: frames[0])
  }

  func dismissAll() {
    for c in cards { c.dismiss() }
  }

  /// The system banner for this notice is gone. A card lives exactly as long as the system
  /// banner of its newest notice; older notices were already replaced by newer ones from the
  /// same app and stay on the card as context, so their going away changes nothing.
  func remove(key: String) {
    guard let card = cards.first(where: { $0.group.latest.key == key }) else { return }
    card.originalGone()
  }

  func layout() {
    for (c, f) in zip(cards, targetFrames()) { c.move(to: f) }
  }

  /// Where the card carrying this notice is drawn, without its shadow margin.
  func cardFrame(forKey key: String) -> NSRect? {
    cards.first { $0.group.notices.contains { $0.key == key } }?.cardFrame
  }

  /// While one card is dragged the rest of the stack keeps formation around it.
  private func follow(_ dragged: CardPanel) {
    let frames = targetFrames()
    guard let i = cards.firstIndex(where: { $0 === dragged }) else { return }
    let dx = dragged.frame.minX - frames[i].minX, dy = dragged.frame.minY - frames[i].minY
    for (c, f) in zip(cards, frames) where c !== dragged {
      c.setFrameOrigin(NSPoint(x: f.minX + dx, y: f.minY + dy))
    }
  }

  /// Where the stack was dropped becomes its place, kept for later cards until an anchor is picked.
  private func dragEnded(_ dragged: CardPanel) {
    let frames = targetFrames()
    guard let i = cards.firstIndex(where: { $0 === dragged }) else { return }
    var offset = settings.offset
    offset.x += dragged.frame.minX - frames[i].minX
    offset.y += dragged.frame.minY - frames[i].minY
    settings.offset = clamped(offset)
  }

  /// Keeps every card of the stack on the chosen display.
  private func clamped(_ offset: NSPoint) -> NSPoint {
    let s = currentScreen.visibleFrame
    let frames = targetFrames(offset: offset)
    guard var stack = frames.first?.insetBy(dx: Style.margin, dy: Style.margin) else { return offset }
    for f in frames.dropFirst() { stack = stack.union(f.insetBy(dx: Style.margin, dy: Style.margin)) }
    var fixed = offset
    if stack.minX < s.minX { fixed.x += s.minX - stack.minX }
    if stack.maxX > s.maxX { fixed.x -= stack.maxX - s.maxX }
    if stack.minY < s.minY { fixed.y += s.minY - stack.minY }
    if stack.maxY > s.maxY { fixed.y -= stack.maxY - s.maxY }
    return fixed
  }

  /// Window frames (card plus transparent margin) for every card, in `cards` order: the stack hangs from
  /// the anchor on the chosen display, shifted by the drag offset. The newest card sits nearest the anchor
  /// edge, so it is on top in the upper and middle rows, at the bottom in the bottom row.
  private func targetFrames(offset: NSPoint? = nil) -> [NSRect] {
    let s = currentScreen.visibleFrame
    let shift = offset ?? settings.offset
    let anchor = settings.anchor
    let heights = cards.map { $0.cardHeight }
    let total = heights.reduce(0, +) + CGFloat(max(0, cards.count - 1)) * Style.gap
    let x: CGFloat
    switch anchor.column {
    case 0: x = s.minX + Style.edgeInset
    case 2: x = s.maxX - Style.edgeInset - Style.width
    default: x = s.midX - Style.width / 2
    }
    let top: CGFloat
    switch anchor.row {
    case 0: top = s.maxY - Style.edgeInset
    case 2: top = s.minY + Style.edgeInset + total
    default: top = s.midY + total / 2
    }
    let order = anchor.isBottom ? Array(cards.indices.reversed()) : Array(cards.indices)
    var frames = [NSRect](repeating: .zero, count: cards.count)
    var y = top
    for i in order {
      y -= heights[i]
      frames[i] = NSRect(x: x - Style.margin + shift.x, y: y - Style.margin + shift.y,
                         width: Style.width + Style.margin * 2, height: heights[i] + Style.margin * 2)
      y -= Style.gap
    }
    return frames
  }
}
