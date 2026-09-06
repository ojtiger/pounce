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
  let pillBorder: NSColor
  let sweep: NSColor
  let blobAlpha: CGFloat
  let wash: NSColor
  let shadowOpacity: Float

  /// Theme and accent from the settings; "system" for either follows macOS at the moment the card is made.
  init(icon: NSImage?) {
    let settings = Settings.shared
    switch settings.theme {
    case .light: isDark = false
    case .dark: isDark = true
    case .system: isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
    let accent = (settings.accent.color ?? NSColor.controlAccentColor).usingColorSpace(.deviceRGB) ?? NSColor.systemBlue
    let h = accent.hueComponent
    tint = accent
    if isDark {
      warm = NSColor(calibratedHue: Palette.wrap(h + 0.09), saturation: 0.85, brightness: 0.95, alpha: 1)
      cool = NSColor(calibratedHue: Palette.wrap(h - 0.14), saturation: 0.9, brightness: 0.9, alpha: 1)
      text = .labelColor
      textSecondary = .secondaryLabelColor
      textTertiary = .secondaryLabelColor
      rim = [NSColor.white.withAlphaComponent(0.42), NSColor.white.withAlphaComponent(0.16),
             NSColor.white.withAlphaComponent(0.1)]
      pillFill = NSColor.white.withAlphaComponent(0.14)
      pillBorder = NSColor.white.withAlphaComponent(0.2)
      sweep = NSColor.white.withAlphaComponent(0.28)
      blobAlpha = 0.38
      wash = NSColor(calibratedHue: h, saturation: 0.5, brightness: 0.2, alpha: 0.28)
      shadowOpacity = 0.55
    } else {
      warm = NSColor(calibratedHue: Palette.wrap(h + 0.09), saturation: 0.5, brightness: 1, alpha: 1)
      cool = NSColor(calibratedHue: Palette.wrap(h - 0.14), saturation: 0.55, brightness: 1, alpha: 1)
      let ink = NSColor(calibratedHue: h, saturation: 0.55, brightness: 0.2, alpha: 1)
      text = .labelColor
      textSecondary = .secondaryLabelColor
      textTertiary = .secondaryLabelColor
      rim = [NSColor.white.withAlphaComponent(1), ink.withAlphaComponent(0.1),
             ink.withAlphaComponent(0.16)]
      pillFill = NSColor.white.withAlphaComponent(0.6)
      pillBorder = ink.withAlphaComponent(0.12)
      sweep = NSColor.white.withAlphaComponent(0.55)
      blobAlpha = 0.22
      wash = NSColor(calibratedHue: h, saturation: 0.12, brightness: 1, alpha: 0.4)
      shadowOpacity = 0.22
    }
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
  private let palette: Palette
  private var dismissWork: DispatchWorkItem?
  private(set) var isClosing = false
  private(set) var cardHeight: CGFloat = 0

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
    shadow.layer?.shadowColor = NSColor.black.cgColor
    shadow.layer?.shadowOpacity = palette.shadowOpacity
    shadow.layer?.shadowRadius = 24
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
    let glass: NSView
    if #available(macOS 26.0, *) {
      let g = NSGlassEffectView()
      g.cornerRadius = Style.corner
      g.style = .regular
      g.tintColor = palette.tint.withAlphaComponent(palette.isDark ? 0.07 : 0.09)
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
    let header = NSStackView(views: [dot(size: 7), appLabel])
    header.orientation = .horizontal
    header.spacing = 7
    header.alignment = .centerY

    let title = NSTextField(wrappingLabelWithString: notice.title)
    title.font = .systemFont(ofSize: 20 * Style.scale, weight: .bold)
    title.textColor = palette.text
    title.shadow = textShadow
    title.maximumNumberOfLines = 2
    title.preferredMaxLayoutWidth = textWidth
    title.isSelectable = false
    title.isHidden = notice.title.isEmpty

    let subtitle = NSTextField(wrappingLabelWithString: notice.subtitle)
    subtitle.font = .systemFont(ofSize: 14.5 * Style.scale, weight: .semibold)
    subtitle.textColor = palette.textSecondary
    subtitle.shadow = textShadow
    subtitle.maximumNumberOfLines = 2
    subtitle.preferredMaxLayoutWidth = textWidth
    subtitle.isSelectable = false
    subtitle.isHidden = notice.subtitle.isEmpty

    let body = NSTextField(wrappingLabelWithString: "")
    let para = NSMutableParagraphStyle()
    para.lineSpacing = 1.5
    para.lineBreakMode = .byWordWrapping
    body.attributedStringValue = NSAttributedString(string: notice.body, attributes: [
      .font: NSFont.systemFont(ofSize: 14.5 * Style.scale), .foregroundColor: palette.textTertiary, .paragraphStyle: para])
    body.font = .systemFont(ofSize: 14.5 * Style.scale)
    body.textColor = palette.textTertiary
    body.shadow = textShadow
    body.maximumNumberOfLines = 4
    body.preferredMaxLayoutWidth = textWidth
    body.isSelectable = false
    body.isHidden = notice.body.isEmpty

    // No action buttons: clicking the card is the default action, X closes.
    buttonActions = []
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

    // Older notices from the same app, newest first.
    let innerWidth = Style.width - Style.padding * 2
    let history = Array(group.notices.dropFirst().prefix(Style.maxHistory))
    let column = NSStackView(views: [row])
    column.orientation = .vertical
    column.alignment = .leading
    column.spacing = 10
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
    return cardHeight
  }

  /// The close button and its countdown ring sit in the card corner, apart from the content layout:
  /// made once, kept through rebuilds, always above whatever the content lays out.
  private func installCorner() {
    if closeButton == nil {
      let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: T("닫기"))!,
                           target: self, action: #selector(closeClicked))
      close.isBordered = false
      close.contentTintColor = palette.text.withAlphaComponent(0.38)
      close.translatesAutoresizingMaskIntoConstraints = false
      let ring = CountdownRing(tint: palette.tint, track: palette.text.withAlphaComponent(0.1), glow: palette.isDark)
      // Catches presses anywhere on the card except the corner, so a drag works over text and icon alike;
      // it handles nothing itself and lets the events climb to the panel.
      let dragCatcher = NSView()
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
        close.widthAnchor.constraint(equalToConstant: 16),
        close.heightAnchor.constraint(equalToConstant: 16),
        ring.centerXAnchor.constraint(equalTo: close.centerXAnchor),
        ring.centerYAnchor.constraint(equalTo: close.centerYAnchor),
        ring.widthAnchor.constraint(equalToConstant: CountdownRing.size),
        ring.heightAnchor.constraint(equalToConstant: CountdownRing.size),
      ])
      closeButton = close
      self.ring = ring
    }
    // A persistent alert has no countdown, exactly like the system's.
    ring?.isHidden = group.isAlert
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

  private func dot(size: CGFloat) -> NSView {
    let d = NSView()
    d.wantsLayer = true
    d.layer?.backgroundColor = palette.tint.cgColor
    d.layer?.cornerRadius = size / 2
    d.layer?.shadowColor = palette.tint.cgColor
    d.layer?.shadowOpacity = 0.8
    d.layer?.shadowRadius = 4
    d.layer?.shadowOffset = .zero
    d.translatesAutoresizingMaskIntoConstraints = false
    d.widthAnchor.constraint(equalToConstant: size).isActive = true
    d.heightAnchor.constraint(equalToConstant: size).isActive = true
    return d
  }

  private func historyRow(_ n: Notice, width: CGFloat) -> NSView {
    let dot = dot(size: 5)

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

    let row = NSStackView(views: [dot, label])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 8
    return row
  }

  private func pill(_ label: String, tag: Int) -> NSButton {
    let b = NSButton(title: label, target: self, action: #selector(actionClicked(_:)))
    b.tag = tag
    b.isBordered = false
    b.wantsLayer = true
    b.layer?.backgroundColor = palette.pillFill.cgColor
    b.layer?.borderColor = palette.pillBorder.cgColor
    b.layer?.borderWidth = 1
    b.layer?.cornerRadius = 14
    let padded = NSMutableAttributedString(string: "  \(label)  ")
    padded.addAttributes([.foregroundColor: palette.text, .font: NSFont.systemFont(ofSize: 13 * Style.scale, weight: .semibold)],
                         range: NSRange(location: 0, length: padded.length))
    b.attributedTitle = padded
    b.translatesAutoresizingMaskIntoConstraints = false
    b.heightAnchor.constraint(equalToConstant: 28).isActive = true
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

  @objc private func actionClicked(_ sender: NSButton) {
    guard buttonActions.indices.contains(sender.tag) else { return }
    onAction?(group.latest, buttonActions[sender.tag])
    dismiss()
  }

  @objc private func closeClicked() {
    guard settled else { return }
    onClose?(group)
    dismiss()
  }

  override func mouseEntered(with event: NSEvent) {
    isHovered = true
    dismissWork?.cancel()
    ring?.freeze()
  }

  override func mouseExited(with event: NSEvent) {
    guard !isDragging else { return }
    isHovered = false
    // A short grace, so a pointer that only brushed past does not take the card with it.
    if dismissWhenMouseLeaves { startDismiss(after: 1.5) } else { scheduleAutoDismiss(after: 1.5) }
  }

  // MARK: drag

  /// The card without its transparent margin, in screen coordinates.
  private var cardRect: NSRect { frame.insetBy(dx: Style.margin, dy: Style.margin) }

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
    guard group.isAlert, !group.isPinned else { return }
    if isHovered { dismissWhenMouseLeaves = true } else { dismiss() }
  }

  /// Banners follow the system banner's own lifetime; this timer is only the fallback.
  /// A persistent alert stays, exactly like the system's, until the user acts on it.
  func scheduleAutoDismiss(after seconds: TimeInterval = Style.showSeconds) {
    dismissWork?.cancel()
    guard !group.isAlert, !isHovered else { return }
    startDismiss(after: seconds)
  }

  /// The countdown itself: the ring drains over `seconds`, then the card goes unless the pointer came back.
  private func startDismiss(after seconds: TimeInterval) {
    logD("card \(group.app): timer \(seconds)s")
    dismissWork?.cancel()
    ring?.drain(over: seconds)
    let work = DispatchWorkItem { [weak self] in
      guard let self, !self.isHovered else { return }
      self.dismiss()
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
final class CountdownRing: NSView {
  static let size: CGFloat = 30
  private let arc = CAShapeLayer()

  init(tint: NSColor, track: NSColor, glow: Bool) {
    super.init(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
    wantsLayer = true
    translatesAutoresizingMaskIntoConstraints = false
    let r = Self.size / 2
    let path = NSBezierPath()
    path.appendArc(withCenter: NSPoint(x: r, y: r), radius: r - 1.5, startAngle: 90, endAngle: -270, clockwise: true)
    let trackLayer = CAShapeLayer()
    for (shape, color) in [(trackLayer, track), (arc, tint)] {
      shape.path = path.cgPath
      shape.fillColor = nil
      shape.strokeColor = color.cgColor
      shape.lineWidth = 1.5
      shape.lineCap = .round
      shape.frame = bounds
      layer?.addSublayer(shape)
    }
    if glow {
      arc.shadowColor = tint.cgColor
      arc.shadowOpacity = 0.45
      arc.shadowRadius = 3
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
    card.onClose = handlers.close
    card.onDismiss = { [weak self, weak card] in
      guard let self, let card else { return }
      self.cards.removeAll { $0 === card }
      self.layout()
    }
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

  /// While one card is dragged the rest of the stack keeps formation around it.
  private func follow(_ dragged: CardPanel) {
    let frames = targetFrames()
    guard let i = cards.firstIndex(where: { $0 === dragged }) else { return }
    let dx = dragged.frame.minX - frames[i].minX, dy = dragged.frame.minY - frames[i].minY
    for (c, f) in zip(cards, frames) where c !== dragged {
      c.setFrameOrigin(NSPoint(x: f.minX + dx, y: f.minY + dy))
    }
  }

  /// Where the stack was dropped becomes its place, kept for later cards until "원래 위치로".
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
