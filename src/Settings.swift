import AppKit
import ServiceManagement

/// Where the stack of cards sits on the chosen display: a 3×3 grid of corners, edges and the centre.
enum Anchor: String, CaseIterable {
  case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight

  var label: String {
    switch self {
    case .topLeft: return "왼쪽 위"
    case .top: return "위 가운데"
    case .topRight: return "오른쪽 위"
    case .left: return "왼쪽 가운데"
    case .center: return "가운데"
    case .right: return "오른쪽 가운데"
    case .bottomLeft: return "왼쪽 아래"
    case .bottom: return "아래 가운데"
    case .bottomRight: return "오른쪽 아래"
    }
  }

  /// Arrow pointing where the cards go; a dot for the centre.
  var symbol: String {
    switch self {
    case .topLeft: return "arrow.up.left"
    case .top: return "arrow.up"
    case .topRight: return "arrow.up.right"
    case .left: return "arrow.left"
    case .center: return "circle.fill"
    case .right: return "arrow.right"
    case .bottomLeft: return "arrow.down.left"
    case .bottom: return "arrow.down"
    case .bottomRight: return "arrow.down.right"
    }
  }

  /// 0 top, 1 middle, 2 bottom.
  var row: Int { (Anchor.allCases.firstIndex(of: self) ?? 4) / 3 }
  /// 0 left, 1 centre, 2 right.
  var column: Int { (Anchor.allCases.firstIndex(of: self) ?? 4) % 3 }
  var isBottom: Bool { row == 2 }

  static func at(row: Int, column: Int) -> Anchor { allCases[row * 3 + column] }
}

/// Light or dark cards, or whatever macOS is showing.
enum Theme: String, CaseIterable {
  case system, light, dark

  var label: String {
    switch self {
    case .system: return "시스템"
    case .light: return "라이트"
    case .dark: return "다크"
    }
  }
}

/// The accent the cards are tinted with: the system's, or one of macOS's own accent colours.
enum Accent: String, CaseIterable {
  case system, blue, purple, pink, red, orange, yellow, green, graphite

  /// nil means the system accent colour.
  var color: NSColor? {
    switch self {
    case .system: return nil
    case .blue: return .systemBlue
    case .purple: return .systemPurple
    case .pink: return .systemPink
    case .red: return .systemRed
    case .orange: return .systemOrange
    case .yellow: return .systemYellow
    case .green: return .systemGreen
    case .graphite: return .systemGray
    }
  }

  var label: String {
    switch self {
    case .system: return "시스템"
    case .blue: return "블루"
    case .purple: return "퍼플"
    case .pink: return "핑크"
    case .red: return "레드"
    case .orange: return "오렌지"
    case .yellow: return "옐로"
    case .green: return "그린"
    case .graphite: return "그래파이트"
    }
  }
}

/// How big the cards are.
enum CardSize: String, CaseIterable {
  case small, normal, large

  var label: String {
    switch self {
    case .small: return "작게"
    case .normal: return "보통"
    case .large: return "크게"
    }
  }

  var scale: CGFloat {
    switch self {
    case .small: return 0.8
    case .normal: return 1
    case .large: return 1.25
    }
  }
}

/// User settings, kept in UserDefaults. Setting one calls `onChange` so the cards move at once.
final class Settings {
  static let shared = Settings()
  private let defaults = UserDefaults.standard
  var onChange: (() -> Void)?
  var onSizeChange: (() -> Void)?
  var onMenuBarChange: (() -> Void)?

  var size: CardSize {
    get { CardSize(rawValue: defaults.string(forKey: "cardSize") ?? "") ?? .normal }
    set { defaults.set(newValue.rawValue, forKey: "cardSize"); onSizeChange?() }
  }

  /// Seconds a banner card stays. Persistent alerts ignore it.
  var duration: TimeInterval {
    get { let v = defaults.double(forKey: "duration"); return v > 0 ? v : 5 }
    set { defaults.set(newValue, forKey: "duration") }
  }

  var theme: Theme {
    get { Theme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system }
    set { defaults.set(newValue.rawValue, forKey: "theme") }
  }

  var accent: Accent {
    get { Accent(rawValue: defaults.string(forKey: "accent") ?? "") ?? .system }
    set { defaults.set(newValue.rawValue, forKey: "accent") }
  }

  /// Name of a macOS system sound played when a card appears; "" means none (only the app's own sound).
  var sound: String {
    get { defaults.string(forKey: "sound") ?? "" }
    set { defaults.set(newValue, forKey: "sound") }
  }

  /// Whether the paw stays off the menu bar. Relaunching the app opens the settings window to bring it back.
  var menuBarHidden: Bool {
    get { defaults.bool(forKey: "menuBarHidden") }
    set { defaults.set(newValue, forKey: "menuBarHidden"); onMenuBarChange?() }
  }

  /// The system sounds a card can chime with.
  static let sounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse",
                       "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

  var anchor: Anchor {
    get { Anchor(rawValue: defaults.string(forKey: "anchor") ?? "") ?? .center }
    set { defaults.set(newValue.rawValue, forKey: "anchor"); onChange?() }
  }

  /// Display ID of the chosen screen; 0 means the primary display (the one with the menu bar).
  var displayID: CGDirectDisplayID {
    get { CGDirectDisplayID(defaults.integer(forKey: "displayID")) }
    set { defaults.set(Int(newValue), forKey: "displayID"); onChange?() }
  }

  /// How far the user dragged the stack away from its anchor. "원래 위치로" zeroes it.
  var offset: NSPoint {
    get { NSPoint(x: defaults.double(forKey: "offsetX"), y: defaults.double(forKey: "offsetY")) }
    set {
      defaults.set(Double(newValue.x), forKey: "offsetX")
      defaults.set(Double(newValue.y), forKey: "offsetY")
      onChange?()
    }
  }

  /// The chosen screen while it is connected, otherwise the display notifications actually appear on:
  /// the one with the menu bar. `NSScreen.screens.first` is not reliably that when several are attached.
  var screen: NSScreen {
    let id = displayID
    if id != 0, let chosen = NSScreen.screens.first(where: { Settings.id(of: $0) == id }) { return chosen }
    return Settings.primaryScreen
  }

  /// The display with the menu bar. In AppKit's global space its frame origin is (0, 0); every other
  /// display is placed relative to it. This is where macOS draws notification banners.
  static var primaryScreen: NSScreen {
    NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main ?? NSScreen.screens.first!
  }

  static func id(of screen: NSScreen) -> CGDirectDisplayID {
    (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
  }
}

/// What the settings window asks the app to do.
struct SettingsActions {
  let sendTest: () -> Void
  let sendFiveTests: () -> Void
  let sendPinnedTest: () -> Void
  let dismissAll: () -> Void
  let openLog: () -> Void
  let quit: () -> Void
}

/// A live miniature of the real desktop with the Pounce card sitting exactly where it will appear:
/// the actual wallpaper behind it, the card at the chosen position, in the chosen theme, accent and size.
/// It shows the card as it truly looks, nothing extra.
final class PreviewCard: NSView {
  private var palette = Palette(icon: nil)
  private var scale: CGFloat = 1
  private var anchor: Anchor = .center
  private var wallpaper: NSImage?
  private var wallpaperURL: URL?
  private let appIcon = NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)!

  override var isFlipped: Bool { false }

  /// Pull the current settings and repaint.
  func apply() {
    palette = Palette(icon: nil)
    // Draw under the chosen theme's appearance, not the window's: the text colours are dynamic, and the
    // real card gets the same treatment. Otherwise a light card in a dark window paints white on white.
    appearance = NSAppearance(named: palette.isDark ? .darkAqua : .aqua)
    scale = Settings.shared.size.scale
    anchor = Settings.shared.anchor
    let url = NSWorkspace.shared.desktopImageURL(for: Settings.shared.screen)
    if url != wallpaperURL { wallpaperURL = url; wallpaper = url.flatMap { NSImage(contentsOf: $0) } }
    needsDisplay = true
  }

  override func draw(_ dirty: NSRect) {
    NSGraphicsContext.current?.cgContext.setShouldAntialias(true)
    let clip = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
    clip.addClip()

    // The real wallpaper, aspect-filled. A neutral wash stands in if it cannot be read.
    if let wp = wallpaper {
      let s = wp.size
      let k = max(bounds.width / s.width, bounds.height / s.height)
      let size = NSSize(width: s.width * k, height: s.height * k)
      wp.draw(in: NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                         width: size.width, height: size.height),
              from: .zero, operation: .sourceOver, fraction: 1)
    } else {
      NSGradient(colors: [NSColor(white: 0.30, alpha: 1), NSColor(white: 0.16, alpha: 1)])!.draw(in: bounds, angle: -90)
    }

    // A faint menu bar for desktop realism.
    let menuH = max(14, bounds.height * 0.07)
    let menuRect = NSRect(x: 0, y: bounds.maxY - menuH, width: bounds.width, height: menuH)
    NSColor.black.withAlphaComponent(0.28).setFill()
    menuRect.fill()

    // Realistic size: a fixed share of the desktop, scaled by the size setting, exactly like the real
    // card (which keeps its width whatever the text). 작게/보통/크게 change the whole card, not just text.
    let cardW = bounds.width * 0.40 * scale
    let u = cardW * 0.05
    let pad = u * 1.5
    let gap = u * 0.9
    let iconSize = u * 2.6
    let appFont = NSFont.systemFont(ofSize: u * 1.0, weight: .semibold)
    let titleFont = NSFont.systemFont(ofSize: u * 1.6, weight: .bold)
    let bodyFont = NSFont.systemFont(ofSize: u * 1.2, weight: .regular)
    let appStr = NSAttributedString(string: "POUNCE", attributes: [.font: appFont, .kern: 1.1])
    let titleStr = NSAttributedString(string: "샘플 알림", attributes: [.font: titleFont])
    let bodyStr = NSAttributedString(string: "이렇게 보입니다", attributes: [.font: bodyFont])
    let dot = u * 0.6
    let contentH = ceil(appStr.size().height + titleStr.size().height + bodyStr.size().height) + u * 0.9
    let cardH = pad * 2 + max(iconSize, contentH)

    let inset = bounds.width * 0.035
    let x: CGFloat
    switch anchor.column {
    case 0: x = inset
    case 2: x = bounds.width - inset - cardW
    default: x = bounds.midX - cardW / 2
    }
    let y: CGFloat
    switch anchor.row {
    case 0: y = bounds.maxY - menuH - inset - cardH
    case 2: y = inset
    default: y = (bounds.minY + (bounds.maxY - menuH)) / 2 - cardH / 2
    }
    let card = NSRect(x: x, y: y, width: cardW, height: cardH)
    let radius = min(cardH, cardW) * 0.24
    let cardPath = NSBezierPath(roundedRect: card, xRadius: radius, yRadius: radius)

    // Shadow + glass base, the same restraint as the real card.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(CGFloat(palette.shadowOpacity))
    shadow.shadowBlurRadius = cardH * 0.18
    shadow.shadowOffset = NSSize(width: 0, height: -cardH * 0.06)
    shadow.set()
    (palette.isDark ? NSColor(white: 0.16, alpha: 0.92) : NSColor(white: 0.99, alpha: 0.94)).setFill()
    cardPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    cardPath.addClip()
    palette.wash.setFill()
    card.fill()
    NSGraphicsContext.restoreGraphicsState()
    palette.rim[0].setStroke()
    cardPath.lineWidth = 1
    cardPath.stroke()

    // Content, vertically centred: icon, then app label + dot, title, body.
    let iconRect = NSRect(x: card.minX + pad, y: card.midY - iconSize / 2, width: iconSize, height: iconSize)
    appIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)

    let textX = iconRect.maxX + gap
    let lineGap = u * 0.35
    let blockH = appStr.size().height + titleStr.size().height + bodyStr.size().height + lineGap * 2
    var lineY = card.midY + blockH / 2
    // app label with accent dot
    lineY -= appStr.size().height
    palette.tint.setFill()
    NSBezierPath(ovalIn: NSRect(x: textX, y: lineY + (appStr.size().height - dot) / 2, width: dot, height: dot)).fill()
    NSAttributedString(string: "POUNCE", attributes: [.font: appFont, .kern: 1.1, .foregroundColor: palette.textTertiary])
      .draw(at: NSPoint(x: textX + dot + 4, y: lineY))
    lineY -= lineGap + titleStr.size().height
    NSAttributedString(string: "샘플 알림", attributes: [.font: titleFont, .foregroundColor: palette.text])
      .draw(at: NSPoint(x: textX, y: lineY))
    lineY -= lineGap + bodyStr.size().height
    NSAttributedString(string: "이렇게 보입니다", attributes: [.font: bodyFont, .foregroundColor: palette.textSecondary])
      .draw(at: NSPoint(x: textX, y: lineY))

    // Countdown ring + close mark, aligned with the app-label row and kept clear of the rounded corner.
    let r = min(pad * 0.7, appStr.size().height * 0.62)
    let cx = card.maxX - pad - r
    let cy = card.midY + blockH / 2 - appStr.size().height / 2
    palette.tint.setStroke()
    let ring = NSBezierPath()
    ring.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: 90, endAngle: -160, clockwise: true)
    ring.lineWidth = 1.4
    ring.lineCapStyle = .round
    ring.stroke()
    palette.textTertiary.setStroke()
    let m = r * 0.42
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: cx - m, y: cy - m)); mark.line(to: NSPoint(x: cx + m, y: cy + m))
    mark.move(to: NSPoint(x: cx - m, y: cy + m)); mark.line(to: NSPoint(x: cx + m, y: cy - m))
    mark.lineWidth = 1.2
    mark.lineCapStyle = .round
    mark.stroke()
  }
}

/// The one settings window: a live preview on top, grouped controls below, styled like a shipping app.
final class SettingsWindow: NSWindowController {
  private let actions: SettingsActions
  private let settings = Settings.shared
  private let preview = PreviewCard()
  private let screenPopup = NSPopUpButton()
  private let tabView = NSTabView()
  private let tabPicker = NSSegmentedControl(labels: ["위치", "테마", "설정"], trackingMode: .selectOne,
                                             target: nil, action: nil)
  private var anchorRows: [NSSegmentedControl] = []
  private let anchorCaption = NSTextField(labelWithString: "")
  private let sizeControl = NSSegmentedControl(labels: CardSize.allCases.map(\.label), trackingMode: .selectOne,
                                               target: nil, action: nil)
  private let durationSlider = NSSlider(value: 5, minValue: 2, maxValue: 30, target: nil, action: nil)
  private let durationLabel = NSTextField(labelWithString: "")
  private let themeControl = NSSegmentedControl(labels: Theme.allCases.map(\.label), trackingMode: .selectOne,
                                                target: nil, action: nil)
  private var accentControl: NSSegmentedControl!
  private let soundPopup = NSPopUpButton()
  private let loginCheck = NSButton(checkboxWithTitle: "로그인 시 실행", target: nil, action: nil)
  private let debugCheck = NSButton(checkboxWithTitle: "디버그 로그", target: nil, action: nil)
  private let menuBarCheck = NSButton(checkboxWithTitle: "메뉴 막대에서 숨기기", target: nil, action: nil)

  init(actions: SettingsActions) {
    self.actions = actions
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
                          styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
    window.title = "Pounce"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .visible
    // Only the close button: the window neither minimises nor zooms, so the other two would sit greyed out.
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    super.init(window: window)
    let form = buildForm()
    window.contentView = form
    form.layoutSubtreeIfNeeded()
    let size = form.fittingSize
    window.setContentSize(NSSize(width: 460, height: max(size.height, 560)))
    window.center()
    NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func show() {
    refresh()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
  }

  // MARK: form

  private func buildForm() -> NSView {
    screenPopup.target = self
    screenPopup.action = #selector(screenChanged)
    sizeControl.target = self
    sizeControl.action = #selector(sizeChanged)
    durationSlider.target = self
    durationSlider.action = #selector(durationChanged)
    durationSlider.isContinuous = true
    durationSlider.numberOfTickMarks = 0
    durationLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    durationLabel.textColor = .secondaryLabelColor
    durationLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true
    themeControl.target = self
    themeControl.action = #selector(themeChanged)
    themeControl.segmentDistribution = .fillEqually
    sizeControl.segmentDistribution = .fillEqually
    accentControl = accentPicker()
    soundPopup.target = self
    soundPopup.action = #selector(soundChanged)
    soundPopup.addItem(withTitle: "없음")
    soundPopup.lastItem?.representedObject = ""
    for name in Settings.sounds {
      soundPopup.addItem(withTitle: name)
      soundPopup.lastItem?.representedObject = name
    }
    loginCheck.target = self
    loginCheck.action = #selector(loginChanged)
    debugCheck.target = self
    debugCheck.action = #selector(debugChanged)
    menuBarCheck.target = self
    menuBarCheck.action = #selector(menuBarChanged)
    screenPopup.setContentHuggingPriority(.init(1), for: .horizontal)
    durationSlider.setContentHuggingPriority(.init(1), for: .horizontal)

    // Preview hero.
    preview.translatesAutoresizingMaskIntoConstraints = false
    preview.wantsLayer = true
    preview.layer?.cornerRadius = 14
    preview.layer?.cornerCurve = .continuous
    preview.layer?.masksToBounds = true
    preview.heightAnchor.constraint(equalToConstant: 236).isActive = true

    let duration = NSStackView(views: [durationSlider, durationLabel])
    duration.spacing = 8
    duration.distribution = .fill
    durationSlider.setContentHuggingPriority(.init(1), for: .horizontal)
    durationLabel.setContentHuggingPriority(.required, for: .horizontal)
    let tests = NSStackView(views: [button("보내기", #selector(sendTest)), button("5회", #selector(sendFiveTests)),
                                    button("고정", #selector(sendPinnedTest))])
    tests.distribution = .fillEqually
    tests.spacing = 6
    let tools = NSStackView(views: [button("로그 열기", #selector(openLog)), button("Pounce 종료", #selector(quitApp))])
    tools.distribution = .fillEqually
    tools.spacing = 6

    // Every control spans the full box width, with its label on top. No empty column on either side.
    tabView.translatesAutoresizingMaskIntoConstraints = false
    tabView.tabViewType = .noTabsNoBorder
    tabPicker.target = self
    tabPicker.action = #selector(tabChanged)
    tabPicker.selectedSegment = 0
    tabView.addTabViewItem(tab("위치", tabContent([
      field("모니터", screenPopup),
      field("위치", anchorGrid()),
      field(nil, button("원래 위치로", #selector(resetPosition))),
      field("크기", sizeControl),
      field("지속 시간", duration),
    ])))
    tabView.addTabViewItem(tab("테마", tabContent([
      field("테마", themeControl),
      field("강조색", accentControl),
      field("소리", soundPopup),
    ])))
    tabView.addTabViewItem(tab("설정", tabContent([
      field("알람 테스트", tests),
      field(nil, button("모든 알람 닫기", #selector(dismissAll))),
      field(nil, loginCheck),
      field(nil, menuBarField()),
      field(nil, debugCheck),
      field(nil, tools),
    ], footer: aboutFooter())))

    // Window background: a soft material for that shipped-app depth.
    let backing = NSVisualEffectView()
    backing.material = .windowBackground
    backing.blendingMode = .behindWindow
    backing.state = .active
    backing.translatesAutoresizingMaskIntoConstraints = false

    // Centre the tab picker so it reads as tabs, not a full-width control.
    tabPicker.setContentHuggingPriority(.required, for: .horizontal)
    let picker = NSView()
    picker.translatesAutoresizingMaskIntoConstraints = false
    tabPicker.translatesAutoresizingMaskIntoConstraints = false
    picker.addSubview(tabPicker)
    NSLayoutConstraint.activate([
      tabPicker.centerXAnchor.constraint(equalTo: picker.centerXAnchor),
      tabPicker.topAnchor.constraint(equalTo: picker.topAnchor),
      tabPicker.bottomAnchor.constraint(equalTo: picker.bottomAnchor),
    ])

    let credit = makerCredit()
    let column = NSStackView(views: [preview, picker, tabView, credit])
    column.orientation = .vertical
    column.alignment = .width
    column.spacing = 12
    column.setCustomSpacing(6, after: tabView)
    column.translatesAutoresizingMaskIntoConstraints = false

    backing.addSubview(column)
    NSLayoutConstraint.activate([
      column.leadingAnchor.constraint(equalTo: backing.leadingAnchor, constant: 20),
      column.trailingAnchor.constraint(equalTo: backing.trailingAnchor, constant: -20),
      column.topAnchor.constraint(equalTo: backing.topAnchor, constant: 36),
      column.bottomAnchor.constraint(equalTo: backing.bottomAnchor, constant: -16),
      preview.leadingAnchor.constraint(equalTo: column.leadingAnchor),
      preview.trailingAnchor.constraint(equalTo: column.trailingAnchor),
      picker.leadingAnchor.constraint(equalTo: column.leadingAnchor),
      picker.trailingAnchor.constraint(equalTo: column.trailingAnchor),
      tabView.leadingAnchor.constraint(equalTo: column.leadingAnchor),
      tabView.trailingAnchor.constraint(equalTo: column.trailingAnchor),
      credit.leadingAnchor.constraint(equalTo: column.leadingAnchor),
      credit.trailingAnchor.constraint(equalTo: column.trailingAnchor),
    ])
    return backing
  }

  private func tab(_ title: String, _ view: NSView) -> NSTabViewItem {
    let item = NSTabViewItem()
    item.label = title
    item.view = view
    return item
  }

  /// A tab's body: full-width fields stacked from the top, with an optional block pinned to the bottom.
  private func tabContent(_ fields: [NSView], footer: NSView? = nil) -> NSView {
    let stack = NSStackView(views: fields)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    let container = NSView()
    container.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
      stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
    ])
    for f in fields { f.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    if let footer {
      footer.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(footer)
      NSLayoutConstraint.activate([
        footer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        footer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        stack.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -16),
      ])
    } else {
      stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12).isActive = true
    }
    return container
  }

  /// The hide checkbox with the way back right under it: a hidden paw leaves no other route to this window.
  private func menuBarField() -> NSView {
    let hint = NSTextField(labelWithString: "숨긴 뒤에는 Pounce 를 다시 실행하면 이 창이 열립니다.")
    hint.font = .systemFont(ofSize: 11)
    hint.textColor = .tertiaryLabelColor
    let v = NSStackView(views: [menuBarCheck, hint])
    v.orientation = .vertical
    v.alignment = .leading
    v.spacing = 3
    return v
  }

  /// The centred about block: app icon, name, version, then the maker's avatar and name.
  private func aboutFooter() -> NSView {
    let icon = NSImageView()
    icon.image = NSApp.applicationIconImage
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.widthAnchor.constraint(equalToConstant: 52).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 52).isActive = true

    let appName = NSTextField(labelWithString: "Pounce")
    appName.font = .systemFont(ofSize: 15, weight: .semibold)
    appName.alignment = .center

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let ver = NSTextField(labelWithString: "버전 \(version)")
    ver.font = .systemFont(ofSize: 11)
    ver.textColor = .secondaryLabelColor
    ver.alignment = .center

    let stack = NSStackView(views: [icon, appName, ver])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 3
    stack.setCustomSpacing(6, after: icon)
    return stack
  }

  /// The maker credit: a small round avatar and the name on one line, for the bottom-right corner.
  private func makerCredit() -> NSView {
    let avatar = NSImageView()
    avatar.image = Self.circularAvatar(diameter: 18)
    avatar.translatesAutoresizingMaskIntoConstraints = false
    avatar.widthAnchor.constraint(equalToConstant: 18).isActive = true
    avatar.heightAnchor.constraint(equalToConstant: 18).isActive = true
    let name = NSTextField(labelWithString: "Tungsten")
    name.font = .systemFont(ofSize: 10, weight: .medium)
    name.textColor = .tertiaryLabelColor
    let row = NSStackView(views: [spacerView(), avatar, name])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 5
    return row
  }

  private func spacerView() -> NSView {
    let v = NSView()
    v.setContentHuggingPriority(.init(1), for: .horizontal)
    v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
    return v
  }


  /// The avatar image cropped to a circle. nil-safe: returns an empty circle if the file is missing.
  private static func circularAvatar(diameter: CGFloat) -> NSImage {
    let src = Bundle.main.path(forResource: "tungsten", ofType: "jpg").flatMap { NSImage(contentsOfFile: $0) }
    return NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
      NSBezierPath(ovalIn: rect).addClip()
      if let src {
        let s = src.size
        let k = max(diameter / s.width, diameter / s.height)
        let d = NSSize(width: s.width * k, height: s.height * k)
        src.draw(in: NSRect(x: (diameter - d.width) / 2, y: (diameter - d.height) / 2, width: d.width, height: d.height))
      } else {
        NSColor.tertiaryLabelColor.setFill()
        rect.fill()
      }
      return true
    }
  }

  /// One row: an optional label on top of a control that fills the full width.
  private func field(_ title: String?, _ control: NSView) -> NSView {
    control.setContentHuggingPriority(.init(1), for: .horizontal)
    if let seg = control as? NSSegmentedControl { seg.segmentDistribution = .fillEqually }
    let v = NSStackView()
    v.orientation = .vertical
    v.alignment = .leading
    v.spacing = 5
    if let title {
      let l = NSTextField(labelWithString: title)
      l.font = .systemFont(ofSize: 11, weight: .medium)
      l.textColor = .secondaryLabelColor
      v.addArrangedSubview(l)
    }
    v.addArrangedSubview(control)
    control.widthAnchor.constraint(equalTo: v.widthAnchor).isActive = true
    return v
  }

  private func accentPicker() -> NSSegmentedControl {
    let control = NSSegmentedControl()
    control.segmentCount = Accent.allCases.count
    control.trackingMode = .selectOne
    control.segmentDistribution = .fillEqually
    control.target = self
    control.action = #selector(accentChanged)
    for (i, accent) in Accent.allCases.enumerated() {
      if let color = accent.color {
        control.setImage(Self.dot(color), forSegment: i)
        control.setWidth(24, forSegment: i)
      } else {
        control.setLabel(accent.label, forSegment: i)
      }
      control.setToolTip(accent.label, forSegment: i)
    }
    return control
  }

  private static func dot(_ color: NSColor) -> NSImage {
    let image = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
      color.setFill()
      NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
      NSColor.black.withAlphaComponent(0.12).setStroke()
      let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
      ring.lineWidth = 0.5
      ring.stroke()
      return true
    }
    return image
  }

  private func anchorGrid() -> NSView {
    let rows = NSStackView()
    rows.orientation = .vertical
    rows.alignment = .width
    rows.spacing = 4
    for row in 0..<3 {
      let images = (0..<3).map { column -> NSImage in
        let anchor = Anchor.at(row: row, column: column)
        return NSImage(systemSymbolName: anchor.symbol, accessibilityDescription: anchor.label)!
      }
      let seg = NSSegmentedControl(images: images, trackingMode: .selectOne, target: self, action: #selector(anchorPicked(_:)))
      seg.tag = row
      seg.segmentDistribution = .fillEqually
      seg.setContentHuggingPriority(.init(1), for: .horizontal)
      anchorRows.append(seg)
      rows.addArrangedSubview(seg)
      seg.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
    }
    anchorCaption.textColor = .secondaryLabelColor
    let box = NSStackView(views: [rows, anchorCaption])
    box.orientation = .vertical
    box.alignment = .leading
    box.spacing = 4
    rows.widthAnchor.constraint(equalTo: box.widthAnchor).isActive = true
    return box
  }

  private func label(_ text: String) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.textColor = .secondaryLabelColor
    l.font = .systemFont(ofSize: NSFont.systemFontSize)
    return l
  }

  private func button(_ title: String, _ action: Selector) -> NSButton {
    let b = NSButton(title: title, target: self, action: action)
    b.bezelStyle = .rounded
    b.setContentHuggingPriority(.init(1), for: .horizontal)
    return b
  }

  @objc private func refresh() {
    screenPopup.removeAllItems()
    let current = Settings.id(of: settings.screen)
    for screen in NSScreen.screens {
      screenPopup.addItem(withTitle: screen.localizedName)
      screenPopup.lastItem?.tag = Int(Settings.id(of: screen))
    }
    screenPopup.selectItem(withTag: Int(current))
    let anchor = settings.anchor
    for seg in anchorRows { seg.selectedSegment = seg.tag == anchor.row ? anchor.column : -1 }
    anchorCaption.stringValue = anchor.label
    sizeControl.selectedSegment = CardSize.allCases.firstIndex(of: settings.size) ?? 1
    durationSlider.doubleValue = settings.duration
    durationLabel.stringValue = "\(Int(settings.duration.rounded()))초"
    themeControl.selectedSegment = Theme.allCases.firstIndex(of: settings.theme) ?? 0
    accentControl.selectedSegment = Accent.allCases.firstIndex(of: settings.accent) ?? 0
    soundPopup.selectItem(at: max(0, ([""] + Settings.sounds).firstIndex(of: settings.sound) ?? 0))
    tabPicker.selectedSegment = max(0, tabView.indexOfTabViewItem(tabView.selectedTabViewItem ?? tabView.tabViewItems[0]))
    loginCheck.state = SMAppService.mainApp.status == .enabled ? .on : .off
    debugCheck.state = Log.shared.debugEnabled ? .on : .off
    menuBarCheck.state = settings.menuBarHidden ? .on : .off
    preview.apply()
  }

  // MARK: actions

  @objc private func tabChanged() {
    tabView.selectTabViewItem(at: tabPicker.selectedSegment)
  }

  @objc private func screenChanged() {
    settings.displayID = CGDirectDisplayID(screenPopup.selectedTag())
    preview.apply()   // show the chosen monitor's own wallpaper right away
  }

  @objc private func anchorPicked(_ sender: NSSegmentedControl) {
    for seg in anchorRows where seg !== sender { seg.selectedSegment = -1 }
    settings.anchor = Anchor.at(row: sender.tag, column: sender.selectedSegment)
    anchorCaption.stringValue = settings.anchor.label
    preview.apply()
  }

  @objc private func sizeChanged() {
    settings.size = CardSize.allCases[sizeControl.selectedSegment]
    preview.apply()
  }

  @objc private func durationChanged() {
    let seconds = durationSlider.doubleValue.rounded()
    settings.duration = seconds
    durationLabel.stringValue = "\(Int(seconds))초"
  }

  @objc private func themeChanged() {
    settings.theme = Theme.allCases[themeControl.selectedSegment]
    preview.apply()
  }

  @objc private func accentChanged() {
    settings.accent = Accent.allCases[accentControl.selectedSegment]
    preview.apply()
  }

  @objc private func soundChanged() {
    let name = (soundPopup.selectedItem?.representedObject as? String) ?? ""
    settings.sound = name
    if !name.isEmpty { NSSound(named: name)?.play() }   // preview it
  }

  @objc private func resetPosition() { settings.offset = .zero }

  @objc private func loginChanged() {
    do {
      if loginCheck.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      logE("login item: \(error)")
      loginCheck.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
  }

  @objc private func debugChanged() {
    UserDefaults.standard.set(debugCheck.state == .on, forKey: "debugLoggingEnabled")
  }

  @objc private func menuBarChanged() { settings.menuBarHidden = menuBarCheck.state == .on }
  @objc private func quitApp() { actions.quit() }

  @objc private func sendTest() { actions.sendTest() }
  @objc private func sendFiveTests() { actions.sendFiveTests() }
  @objc private func sendPinnedTest() { actions.sendPinnedTest() }
  @objc private func dismissAll() { actions.dismissAll() }
  @objc private func openLog() { actions.openLog() }
}
