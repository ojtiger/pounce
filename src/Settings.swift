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
    case .small: return 0.85
    case .normal: return 1
    case .large: return 1.2
    }
  }
}

/// User settings, kept in UserDefaults. Setting one calls `onChange` so the cards move at once.
final class Settings {
  static let shared = Settings()
  private let defaults = UserDefaults.standard
  var onChange: (() -> Void)?
  var onSizeChange: (() -> Void)?

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
}

/// The one settings window: display and position, test notifications, general switches.
final class SettingsWindow: NSWindowController {
  private let actions: SettingsActions
  private let settings = Settings.shared
  private let screenPopup = NSPopUpButton()
  private var anchorRows: [NSSegmentedControl] = []
  private let anchorCaption = NSTextField(labelWithString: "")
  private let sizeControl = NSSegmentedControl(labels: CardSize.allCases.map(\.label), trackingMode: .selectOne,
                                               target: nil, action: nil)
  private let durationSlider = NSSlider(value: 5, minValue: 2, maxValue: 30, target: nil, action: nil)
  private let durationLabel = NSTextField(labelWithString: "")
  private let themeControl = NSSegmentedControl(labels: Theme.allCases.map(\.label), trackingMode: .selectOne,
                                                target: nil, action: nil)
  private var accentControl: NSSegmentedControl!
  private let loginCheck = NSButton(checkboxWithTitle: "로그인 시 실행", target: nil, action: nil)
  private let debugCheck = NSButton(checkboxWithTitle: "디버그 로그", target: nil, action: nil)

  init(actions: SettingsActions) {
    self.actions = actions
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "CentreGrowl 설정"
    window.isReleasedWhenClosed = false
    super.init(window: window)
    let form = buildForm()
    window.contentView = form
    form.layoutSubtreeIfNeeded()
    let size = form.fittingSize
    window.setContentSize(NSSize(width: max(size.width, 460), height: size.height))
    window.center()
    NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func show() {
    refresh()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    // Cooperative activation may refuse; the window still has to come up.
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
    durationLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true
    themeControl.target = self
    themeControl.action = #selector(themeChanged)
    accentControl = accentPicker()
    loginCheck.target = self
    loginCheck.action = #selector(loginChanged)
    debugCheck.target = self
    debugCheck.action = #selector(debugChanged)
    screenPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
    durationSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true

    let duration = NSStackView(views: [durationSlider, durationLabel])
    duration.spacing = 8
    let tests = NSStackView(views: [button("보내기", #selector(sendTest)), button("5회", #selector(sendFiveTests)),
                                    button("고정", #selector(sendPinnedTest))])
    tests.spacing = 6
    let logs = NSStackView(views: [debugCheck, button("로그 열기", #selector(openLog))])
    logs.spacing = 12

    let sections = NSStackView(views: [
      section("표시", [
        [label("모니터"), screenPopup],
        [label("위치"), anchorGrid()],
        [NSGridCell.emptyContentView, button("원래 위치로", #selector(resetPosition))],
        [label("크기"), sizeControl],
        [label("지속 시간"), duration],
      ]),
      section("모양", [
        [label("테마"), themeControl],
        [label("강조색"), accentControl],
      ]),
      section("테스트", [
        [label("알람"), tests],
        [NSGridCell.emptyContentView, button("모든 알람 닫기", #selector(dismissAll))],
      ]),
      section("일반", [
        [NSGridCell.emptyContentView, loginCheck],
        [NSGridCell.emptyContentView, logs],
      ]),
    ])
    sections.orientation = .vertical
    sections.alignment = .leading
    sections.spacing = 12
    sections.translatesAutoresizingMaskIntoConstraints = false
    // Every group spans the window, whatever its content needs.
    for group in sections.arrangedSubviews {
      group.widthAnchor.constraint(equalTo: sections.widthAnchor).isActive = true
    }

    let box = NSView()
    box.addSubview(sections)
    NSLayoutConstraint.activate([
      sections.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
      sections.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20),
      sections.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
      sections.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -20),
    ])
    return box
  }

  /// One titled group: a label column on the left, controls on the right.
  private func section(_ title: String, _ rows: [[NSView]]) -> NSBox {
    let grid = NSGridView(views: rows)
    grid.rowSpacing = 8
    grid.columnSpacing = 12
    grid.yPlacement = .center
    grid.column(at: 0).xPlacement = .trailing
    grid.column(at: 0).width = 64
    grid.translatesAutoresizingMaskIntoConstraints = false
    let box = NSBox()
    box.title = title
    box.titleFont = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    box.translatesAutoresizingMaskIntoConstraints = false
    box.setContentHuggingPriority(.init(1), for: .horizontal)
    // Pinned inside the box's own content view, so the box takes its height from the grid.
    let content = box.contentView!
    content.addSubview(grid)
    NSLayoutConstraint.activate([
      grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
      grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -10),
      grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
      grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
    ])
    return box
  }

  /// "시스템" and then a dot of each macOS accent colour.
  private func accentPicker() -> NSSegmentedControl {
    let control = NSSegmentedControl()
    control.segmentCount = Accent.allCases.count
    control.trackingMode = .selectOne
    control.target = self
    control.action = #selector(accentChanged)
    for (i, accent) in Accent.allCases.enumerated() {
      if let color = accent.color {
        control.setImage(Self.dot(color), forSegment: i)
        control.setWidth(26, forSegment: i)
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
      return true
    }
    image.isTemplate = false
    return image
  }

  /// Three rows of three: arrows pointing where the cards go, a dot for the centre, one lit at a time.
  private func anchorGrid() -> NSView {
    let rows = NSStackView()
    rows.orientation = .vertical
    rows.alignment = .leading
    rows.spacing = 4
    for row in 0..<3 {
      let images = (0..<3).map { column -> NSImage in
        let anchor = Anchor.at(row: row, column: column)
        return NSImage(systemSymbolName: anchor.symbol, accessibilityDescription: anchor.label)!
      }
      let seg = NSSegmentedControl(images: images, trackingMode: .selectOne, target: self, action: #selector(anchorPicked(_:)))
      seg.tag = row
      for i in 0..<3 { seg.setWidth(34, forSegment: i) }
      anchorRows.append(seg)
      rows.addArrangedSubview(seg)
    }
    anchorCaption.textColor = .secondaryLabelColor
    let box = NSStackView(views: [rows, anchorCaption])
    box.spacing = 12
    box.alignment = .centerY
    return box
  }

  private func label(_ text: String) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.textColor = .secondaryLabelColor
    return l
  }

  private func button(_ title: String, _ action: Selector) -> NSButton {
    let b = NSButton(title: title, target: self, action: action)
    b.bezelStyle = .rounded
    return b
  }

  /// Current values into the controls; screens can come and go, so the list is rebuilt each time.
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
    loginCheck.state = SMAppService.mainApp.status == .enabled ? .on : .off
    debugCheck.state = Log.shared.debugEnabled ? .on : .off
  }

  // MARK: actions

  @objc private func screenChanged() {
    settings.displayID = CGDirectDisplayID(screenPopup.selectedTag())
  }

  @objc private func anchorPicked(_ sender: NSSegmentedControl) {
    for seg in anchorRows where seg !== sender { seg.selectedSegment = -1 }
    settings.anchor = Anchor.at(row: sender.tag, column: sender.selectedSegment)
    anchorCaption.stringValue = settings.anchor.label
  }

  @objc private func sizeChanged() {
    settings.size = CardSize.allCases[sizeControl.selectedSegment]
  }

  @objc private func durationChanged() {
    let seconds = durationSlider.doubleValue.rounded()
    settings.duration = seconds
    durationLabel.stringValue = "\(Int(seconds))초"
  }

  @objc private func themeChanged() {
    settings.theme = Theme.allCases[themeControl.selectedSegment]
  }

  @objc private func accentChanged() {
    settings.accent = Accent.allCases[accentControl.selectedSegment]
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

  @objc private func sendTest() { actions.sendTest() }
  @objc private func sendFiveTests() { actions.sendFiveTests() }
  @objc private func sendPinnedTest() { actions.sendPinnedTest() }
  @objc private func dismissAll() { actions.dismissAll() }
  @objc private func openLog() { actions.openLog() }
}
