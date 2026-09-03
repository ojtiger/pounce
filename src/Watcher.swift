import AppKit
import ApplicationServices

/// One captured notification, read from the system banner before it became visible.
struct Notice {
  let app: String
  let title: String
  let subtitle: String
  let body: String
  let isAlert: Bool
  /// The hidden system banner.
  let element: AXUIElement?
  /// Notification UUID when known.
  let uuid: String
  let icon: NSImage?
  /// Buttons the system banner offers (보기, 답장, 닫기 …).
  let actions: [AXAction]

  /// Identity for de-duplication and lifetime tracking.
  var key: String { uuid.isEmpty ? "\(app)|\(title)|\(subtitle)|\(body)" : uuid }
}

private enum K {
  static let ncBundle = "com.apple.notificationcenterui"
  static let bannerSubroles: Set<String> = ["AXNotificationCenterBanner", "AXNotificationCenterAlert"]
  static let widgetEditorButton = "widget-editor-button"
  static let widgetPrefix = "widget-local:"
  static let maxNodes = 4000
  /// How far above the primary display the Notification Center window is parked.
  static let parkOffset: CGFloat = 5000
}

private enum WindowKind {
  case banners([AXUIElement])
  case empty
  case skip(String)
}

private func axCallback(
  _: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
  guard let refcon else { return }
  Unmanaged<Watcher>.fromOpaque(refcon).takeUnretainedValue().handle(notification as String, element)
}

/// Watches the Notification Center process, parks its banner window off-screen the moment a
/// banner is created, hands the banner's content to `onNotice`, and reports when a banner is gone.
final class Watcher {
  var onNotice: ((Notice) -> Void)?
  /// A banner that was reported earlier no longer exists (timed out, clicked, withdrawn).
  var onGone: ((String) -> Void)?
  /// Accessibility permission disappeared while running.
  var onLostTrust: (() -> Void)?

  /// While paused (screen locked) nothing is hidden or reported; the system keeps its banners.
  var isPaused = false {
    didSet {
      guard isPaused != oldValue else { return }
      if isPaused { restoreAll() } else { scan() }
      logI(isPaused ? "paused" : "resumed")
    }
  }

  private var observer: AXObserver?
  private var appElement: AXUIElement?
  private var watchedPID: pid_t = 0
  private var observedWindows = Set<AXUIElement>()
  private var parkedOrigins = [AXUIElement: CGPoint]()
  private var releasedWindows = Set<AXUIElement>()
  private var loggedSkips = Set<AXUIElement>()
  private var seenKeys = [String: Date]()
  private var liveKeys = Set<String>()
  private var pendingRescan = false
  private var dumpedBanners = 0
  private var holdTimer: Timer?
  private var holdTicks = 0
  private var safetyTimer: Timer?

  var isRunning: Bool { observer != nil }

  // MARK: lifecycle

  func start() -> Bool {
    stop()
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: K.ncBundle).first else {
      logE("Notification Center is not running")
      return false
    }
    var obs: AXObserver?
    guard AXObserverCreate(app.processIdentifier, axCallback, &obs) == .success, let obs else {
      logE("AXObserverCreate failed")
      return false
    }
    observer = obs
    watchedPID = app.processIdentifier
    let element = AXUIElementCreateApplication(app.processIdentifier)
    appElement = element
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
    register(kAXWindowCreatedNotification, on: element, label: "app")
    register("AXChildrenChanged", on: element, label: "app")
    for w in windows() { observe(window: w) }
    logI("watching Notification Center pid=\(app.processIdentifier)")
    recoverStrandedWindows()
    startSafetyTimer()
    scan()
    return true
  }

  func stop() {
    restoreAll()
    safetyTimer?.invalidate()
    safetyTimer = nil
    holdTimer?.invalidate()
    holdTimer = nil
    if let obs = observer {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
    }
    observer = nil
    appElement = nil
    observedWindows.removeAll()
    loggedSkips.removeAll()
    releasedWindows.removeAll()
    seenKeys.removeAll()
    liveKeys.removeAll()
  }

  /// A previous instance killed without cleanup leaves the window parked off-screen; bring it back.
  private func recoverStrandedWindows() {
    for w in windows() {
      guard let f = w.frame(), f.minY <= -K.parkOffset / 2 else { continue }
      let r = w.setPosition(CGPoint(x: f.minX, y: f.minY + K.parkOffset))
      logI("recovered stranded window from \(NSStringFromRect(f)) result=\(r.name)")
    }
  }

  /// Events from Notification Center are not fully reliable; look once a second regardless,
  /// follow a relaunched Notification Center, and notice when permission is taken away.
  private func startSafetyTimer() {
    safetyTimer?.invalidate()
    safetyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self else { return }
      if !AXIsProcessTrusted() {
        logE("Accessibility permission lost")
        self.stop()
        self.onLostTrust?()
        return
      }
      let current = NSRunningApplication.runningApplications(withBundleIdentifier: K.ncBundle).first?.processIdentifier
      if let current, current != self.watchedPID {
        logI("Notification Center pid changed \(self.watchedPID) -> \(current); re-attaching")
        _ = self.start()
        return
      }
      self.scan()
    }
  }

  func restoreAll() {
    for (w, origin) in parkedOrigins {
      let r = w.setPosition(origin)
      logD("restore all result=\(r.name)")
    }
    parkedOrigins.removeAll()
  }

  /// Put the window holding this banner back on screen and stop hiding it until it empties.
  /// Used when the user must see the system's own UI (a reply field, a lingering alert).
  func release(_ banner: AXUIElement) {
    for w in Array(parkedOrigins.keys) {
      releasedWindows.insert(w)
      restore(w, reason: "released")
    }
  }

  // MARK: events

  fileprivate func handle(_ notification: String, _ element: AXUIElement) {
    logD("event \(notification) on \(element.role ?? "?")[\(element.subrole ?? "-")]")
    if notification == kAXWindowCreatedNotification as String { observe(window: element) }
    if notification == kAXUIElementDestroyedNotification as String {
      releasedWindows.remove(element)
      if parkedOrigins.removeValue(forKey: element) != nil { observedWindows.remove(element) }
    }
    scan()
  }

  private func windows() -> [AXUIElement] {
    appElement?.attr(kAXWindowsAttribute, as: [AXUIElement].self) ?? []
  }

  private func observe(window: AXUIElement) {
    guard observedWindows.insert(window).inserted else { return }
    register("AXChildrenChanged", on: window, label: "window")
    register(kAXCreatedNotification, on: window, label: "window")
    register(kAXUIElementDestroyedNotification, on: window, label: "window")
  }

  private func register(_ name: String, on element: AXUIElement, label: String) {
    guard let obs = observer else { return }
    let refcon = Unmanaged.passUnretained(self).toOpaque()
    let r = AXObserverAddNotification(obs, element, name as CFString, refcon)
    if r != .success && r != .notificationAlreadyRegistered {
      logE("register \(name) on \(label) failed: \(r.name)")
    }
  }

  // MARK: scanning

  private func scan() {
    guard isRunning, !isPaused else { return }
    var present = Set<String>()
    for w in windows() {
      observe(window: w)
      switch classify(w) {
      case .skip(let why):
        if loggedSkips.insert(w).inserted { logD("skip window: \(why)") }
      case .empty:
        releasedWindows.remove(w)
        restore(w, reason: "no banner")
      case .banners(let banners):
        park(w)
        for b in banners {
          guard let notice = extract(b) else {
            if !pendingRescan {
              // Text not populated yet; look again shortly.
              pendingRescan = true
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.pendingRescan = false
                self?.scan()
              }
            }
            continue
          }
          let key = notice.key
          present.insert(key)
          let now = Date()
          if liveKeys.contains(key) { seenKeys[key] = now; continue }
          if let t = seenKeys[key], now.timeIntervalSince(t) < 60 { continue }
          seenKeys[key] = now
          logI("notice app=\"\(notice.app)\" title=\"\(notice.title)\" alert=\(notice.isAlert) key=\(key.prefix(8))")
          onNotice?(notice)
        }
      }
    }
    // Banners that were live a moment ago and are not any more.
    for key in liveKeys.subtracting(present) {
      logD("gone \(key.prefix(8))")
      onGone?(key)
    }
    liveKeys = present
    let cutoff = Date().addingTimeInterval(-120)
    seenKeys = seenKeys.filter { $0.value > cutoff }
  }

  private func classify(_ root: AXUIElement) -> WindowKind {
    var pending = [root]
    var visited = Set<AXUIElement>()
    var banners: [AXUIElement] = []
    var hasWidget = false
    while let el = pending.popLast() {
      guard visited.insert(el).inserted else { continue }
      if visited.count > K.maxNodes { return .skip("too many nodes") }
      if let id = el.identifier {
        // The Notification Center panel (clock click) lists old notifications; leave it alone.
        if id == K.widgetEditorButton { return .skip("notification center panel") }
        if id.hasPrefix(K.widgetPrefix) { hasWidget = true }
      }
      if let s = el.subrole, K.bannerSubroles.contains(s) {
        banners.append(el)
        continue
      }
      pending.append(contentsOf: el.children().reversed())
    }
    // A window that holds banners is a banner window even if desktop widgets share it.
    if !banners.isEmpty { return .banners(banners) }
    return hasWidget ? .skip("desktop widget") : .empty
  }

  // MARK: park / restore

  private func park(_ window: AXUIElement) {
    guard !releasedWindows.contains(window) else { return }
    if parkedOrigins[window] == nil {
      guard let frame = window.frame() else { return }
      guard window.isSettable(kAXPositionAttribute) else {
        logE("window position not settable")
        return
      }
      parkedOrigins[window] = frame.origin
      logD("park baseline window=\(NSStringFromRect(frame))")
      startHoldTimer()
    }
    hold(window, force: true)
  }

  /// Notification Center may put its window back at any time (re-layout, dismiss animation),
  /// so while anything is parked we check often and push it away again, and re-scan for
  /// banners that stacked into the window without raising an event.
  private func startHoldTimer() {
    guard holdTimer == nil else { return }
    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      guard let self else { return }
      if self.parkedOrigins.isEmpty {
        self.holdTimer?.invalidate()
        self.holdTimer = nil
        return
      }
      for w in Array(self.parkedOrigins.keys) { self.hold(w, force: false) }
      self.holdTicks += 1
      if self.holdTicks % 2 == 0 { self.scan() }
    }
  }

  private func hold(_ window: AXUIElement, force: Bool) {
    guard let origin = parkedOrigins[window] else { return }
    let target = CGPoint(x: origin.x, y: origin.y - K.parkOffset)
    if !force {
      guard let current = window.point() else {
        parkedOrigins.removeValue(forKey: window)
        logD("parked window gone")
        return
      }
      if abs(current.y - target.y) < 1 { return }
      logD("snapped back to \(NSStringFromPoint(current)); re-parking")
    }
    let r = window.setPosition(target)
    logD("park result=\(r.name)")
  }

  private func restore(_ window: AXUIElement, reason: String) {
    guard let origin = parkedOrigins[window] else { return }
    let r = window.setPosition(origin)
    logD("restore reason=\(reason) result=\(r.name)")
    if r == .success || r == .invalidUIElement { parkedOrigins.removeValue(forKey: window) }
  }

  // MARK: content

  private func extract(_ banner: AXUIElement) -> Notice? {
    if dumpedBanners < 3 {
      dumpedBanners += 1
      var lines: [String] = []
      banner.dump(into: &lines)
      logD("banner tree:\n" + lines.joined(separator: "\n"))
    }
    var fields = [String: String]()
    var others: [String] = []
    collectTexts(banner, depth: 0, fields: &fields, others: &others)
    let title = fields["title"] ?? others.first ?? ""
    let subtitle = fields["subtitle"] ?? ""
    let body = fields["body"] ?? (fields["title"] == nil ? others.dropFirst().joined(separator: "\n") : others.joined(separator: "\n"))
    // The banner's description reads "<app name> <title>, <subtitle>, <body>".
    let desc = cleanAX(banner.desc ?? banner.attributedDescription ?? "")
    var app = cleanAX(desc.components(separatedBy: ", ").first ?? desc)
    if !title.isEmpty, app.hasSuffix(title) { app = cleanAX(String(app.dropLast(title.count))) }
    guard !title.isEmpty || !body.isEmpty || !app.isEmpty else { return nil }
    let uuid = (banner.identifier ?? "").uppercased()
    return Notice(app: app, title: title, subtitle: subtitle, body: body,
                  isAlert: banner.subrole == "AXNotificationCenterAlert",
                  element: banner, uuid: uuid.count == 36 ? uuid : "",
                  icon: AppIcons.shared.icon(named: app), actions: banner.customActions())
  }

  private func collectTexts(_ el: AXUIElement, depth: Int, fields: inout [String: String], others: inout [String]) {
    guard depth < 8 else { return }
    if el.role == kAXStaticTextRole as String, let v = el.value {
      let c = cleanAX(v)
      if !c.isEmpty {
        if let id = el.identifier, ["title", "subtitle", "body"].contains(id), fields[id] == nil {
          fields[id] = c
        } else {
          others.append(c)
        }
      }
    }
    for child in el.children() { collectTexts(child, depth: depth + 1, fields: &fields, others: &others) }
  }
}

/// Finds apps by their localized display name (what the banner shows), e.g. "스크립트 편집기".
final class AppIcons {
  static let shared = AppIcons()
  private var pathByName = [String: String]()
  private var scanned = false

  func icon(named name: String) -> NSImage? {
    guard !name.isEmpty else { return nil }
    if let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) {
      return running.icon
    }
    if let path = path(named: name) { return NSWorkspace.shared.icon(forFile: path) }
    return nil
  }

  func path(named name: String) -> String? {
    if !scanned { scan() }
    return pathByName[name]
  }

  private func scan() {
    scanned = true
    let fm = FileManager.default
    let dirs = ["/Applications", "/Applications/Utilities", NSHomeDirectory() + "/Applications",
                "/System/Applications", "/System/Applications/Utilities", "/System/Library/CoreServices"]
    for dir in dirs {
      for entry in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] where entry.hasSuffix(".app") {
        let path = "\(dir)/\(entry)"
        var display = fm.displayName(atPath: path)
        if display.hasSuffix(".app") { display = String(display.dropLast(4)) }
        if pathByName[display] == nil { pathByName[display] = path }
        let plain = String(entry.dropLast(4))
        if pathByName[plain] == nil { pathByName[plain] = path }
      }
    }
    logD("app icon index: \(pathByName.count) apps")
  }
}
