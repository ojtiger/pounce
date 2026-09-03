import AppKit
import QuartzCore

enum Style {
  static let width: CGFloat = 480
  /// Transparent margin around the card so the pop overshoot and shadow are not clipped.
  static let margin: CGFloat = 56
  static let padding: CGFloat = 22
  static let iconSize: CGFloat = 56
  static let corner: CGFloat = 28
  static let gap: CGFloat = 14
  static let showSeconds: TimeInterval = 8
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

  /// Follows the system appearance and the system accent colour at the moment the card is made.
  init(icon: NSImage?) {
    isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    let accent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? NSColor.systemBlue
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
  private(set) var notices: [Notice]

  init(_ notice: Notice) {
    app = notice.app
    icon = notice.icon
    notices = [notice]
  }

  var latest: Notice { notices[0] }
  var isAlert: Bool { notices.contains { $0.isAlert } }
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
  private var presentedAt = Date.distantPast
  private var isHovered = false
  private var dismissWhenMouseLeaves = false
  private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  private let root = NSView()
  private let glassHost = NSView()
  private var contentHost = NSView()
  private var sheen: Sheen!
  private var content: NSView?
  private var iconView: NSImageView?
  private var buttonActions: [AXAction] = []
  private let palette: Palette
  private var dismissWork: DispatchWorkItem?
  private var isClosing = false
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
    let notice = group.latest
    let textShadow = NSShadow()
    textShadow.shadowColor = NSColor.clear
    textShadow.shadowBlurRadius = 5
    textShadow.shadowOffset = NSSize(width: 0, height: -1)

    let icon = NSImageView()
    icon.image = group.icon ?? NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)
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

    let textWidth = Style.width - Style.padding * 2 - Style.iconSize - 16

    let appLabel = NSTextField(labelWithString: "")
    let appText = NSMutableAttributedString(string: group.app.uppercased())
    appText.addAttributes([
      .kern: 1.3, .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
      .foregroundColor: palette.textTertiary,
    ], range: NSRange(location: 0, length: appText.length))
    appLabel.attributedStringValue = appText
    appLabel.lineBreakMode = .byTruncatingTail
    appLabel.maximumNumberOfLines = 1
    let header = NSStackView(views: [dot(size: 7), appLabel])
    header.orientation = .horizontal
    header.spacing = 7
    header.alignment = .centerY
    if group.notices.count > 1 {
      header.addArrangedSubview(badge("\(group.notices.count)"))
    }

    let title = NSTextField(wrappingLabelWithString: notice.title)
    title.font = .systemFont(ofSize: 20, weight: .bold)
    title.textColor = palette.text
    title.shadow = textShadow
    title.maximumNumberOfLines = 2
    title.preferredMaxLayoutWidth = textWidth
    title.isSelectable = false

    let subtitle = NSTextField(wrappingLabelWithString: notice.subtitle)
    subtitle.font = .systemFont(ofSize: 14.5, weight: .semibold)
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
      .font: NSFont.systemFont(ofSize: 14.5), .foregroundColor: palette.textTertiary, .paragraphStyle: para])
    body.font = .systemFont(ofSize: 14.5)
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
        let rest = NSTextField(labelWithString: "그리고 \(more)개 더")
        rest.font = .systemFont(ofSize: 12, weight: .medium)
        rest.textColor = palette.textTertiary
        column.addArrangedSubview(rest)
      }
    }
    column.translatesAutoresizingMaskIntoConstraints = false
    contentHost.addSubview(column)

    let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "닫기")!,
                         target: self, action: #selector(closeClicked))
    close.isBordered = false
    close.contentTintColor = palette.text.withAlphaComponent(0.38)
    close.translatesAutoresizingMaskIntoConstraints = false
    column.addSubview(close)

    NSLayoutConstraint.activate([
      column.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor, constant: Style.padding),
      column.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: Style.padding),
      column.trailingAnchor.constraint(lessThanOrEqualTo: contentHost.trailingAnchor, constant: -Style.padding),
      close.topAnchor.constraint(equalTo: contentHost.topAnchor, constant: 15),
      close.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor, constant: -15),
      close.widthAnchor.constraint(equalToConstant: 16),
      close.heightAnchor.constraint(equalToConstant: 16),
    ])
    content = column

    root.layoutSubtreeIfNeeded()
    cardHeight = max(Style.iconSize + Style.padding * 2, column.fittingSize.height + Style.padding * 2)
    return cardHeight
  }

  private func badge(_ text: String) -> NSView {
    let label = NSTextField(labelWithString: text)
    label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
    label.textColor = .white
    label.alignment = .center
    label.wantsLayer = true
    label.layer?.backgroundColor = palette.tint.cgColor
    label.layer?.cornerRadius = 9
    label.translatesAutoresizingMaskIntoConstraints = false
    label.heightAnchor.constraint(equalToConstant: 18).isActive = true
    label.widthAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
    return label
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
      .font: NSFont.systemFont(ofSize: 12.5, weight: .semibold), .foregroundColor: palette.textSecondary]))
    let tail = [n.subtitle, n.body].filter { !$0.isEmpty }.joined(separator: " · ")
    if !tail.isEmpty {
      line.append(NSAttributedString(string: "  " + tail, attributes: [
        .font: NSFont.systemFont(ofSize: 12.5), .foregroundColor: palette.textTertiary]))
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
    padded.addAttributes([.foregroundColor: palette.text, .font: NSFont.systemFont(ofSize: 13, weight: .semibold)],
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
  }

  override func mouseExited(with event: NSEvent) {
    isHovered = false
    if dismissWhenMouseLeaves { dismiss(); return }
    scheduleAutoDismiss(after: 1.5)
  }

  /// The system banner behind this card is gone; follow it, unless the user is looking at it.
  func originalGone() {
    if isHovered { dismissWhenMouseLeaves = true } else { dismiss() }
  }

  /// Banners follow the system banner's own lifetime; this timer is only the fallback.
  /// A persistent alert stays, exactly like the system's, until the user acts on it.
  func scheduleAutoDismiss(after seconds: TimeInterval = Style.showSeconds) {
    dismissWork?.cancel()
    guard !group.isAlert else { return }
    let work = DispatchWorkItem { [weak self] in self?.dismiss() }
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
    let p = glassHost.convert(event.locationInWindow, from: nil)
    return !(glassHost.hitTest(p) is NSButton)
  }
}

// MARK: - Manager

/// Handlers the app supplies for what a card can do with the original system notification.
struct CardHandlers {
  let activate: (Notice) -> Void
  let action: (Notice, AXAction) -> Void
  let close: (NoticeGroup) -> Void
}

/// One card per app, newest group on top, the stack centred on the primary display.
final class CardManager {
  private var cards: [CardPanel] = []
  private let handlers: CardHandlers

  init(handlers: CardHandlers) { self.handlers = handlers }

  func add(_ notice: Notice) {
    if !notice.app.isEmpty, let existing = cards.first(where: { $0.group.app == notice.app }) {
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

  private func layout() {
    for (c, f) in zip(cards, targetFrames()) { c.move(to: f) }
  }

  /// Always the primary display (the one with the menu bar), whatever the mouse is doing.
  private func screen() -> NSScreen {
    NSScreen.screens.first ?? NSScreen.main!
  }

  /// Window frames (card plus transparent margin) stacked so the group is centred on screen.
  private func targetFrames() -> [NSRect] {
    let s = screen().visibleFrame
    let heights = cards.map { $0.cardHeight }
    let total = heights.reduce(0, +) + CGFloat(max(0, cards.count - 1)) * Style.gap
    var y = s.midY + total / 2
    let x = s.midX - Style.width / 2
    return heights.map { h in
      y -= h
      let f = NSRect(x: x - Style.margin, y: y - Style.margin,
                     width: Style.width + Style.margin * 2, height: h + Style.margin * 2)
      y -= Style.gap
      return f
    }
  }
}
