import AppKit
import ApplicationServices

/// One captured notification, read from the system banner before it became visible.
struct Notice {
  let app: String
  let title: String
  let subtitle: String
  let body: String
  var isAlert: Bool
  /// The hidden system banner.
  let element: AXUIElement?
  /// Notification UUID when known.
  let uuid: String
  let icon: NSImage?
  /// Buttons the system banner offers (보기, 답장, 닫기 …). Ones known not to work are dropped
  /// before the card is built.
  var actions: [AXAction]
  /// The banner carried a picture. Accessibility gives its size and nothing else — no pixels, no
  /// file — so the card can only say that one is there.
  var hasImage = false
  /// When it reached us. Each notice ages out of its card on its own, so one that lingers cannot
  /// keep the rest on screen with it.
  var arrived = Date()
  /// The display the banner appeared on (a CGDirectDisplayID); 0 when unknown. The card centres here,
  /// so it lands where the notification was, whatever the display arrangement or resolution.
  var screenNumber: UInt32 = 0
  /// Stays until the user closes it, whatever the system banner behind it does. Only the pinned test
  /// sets this: it goes out as a real notification, and the system may still show it as a plain banner.
  var pinned = false
  /// Relayed from the mirrored iPhone. A different source than the same app on this Mac, so it gets its
  /// own card rather than merging with the Mac app's notifications.
  var fromIPhone = false

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
  /// How long the window stays parked after its last banner is gone from the tree.
  /// The system keeps drawing the banner's fade-out for a few frames after that, so putting the
  /// window back right away shows the tail of the animation in the corner.
  static let emptyGrace: TimeInterval = 0.7
  /// How long any single accessibility call may take before it is abandoned as unanswered. Well
  /// under the system default so a wedged Notification Center cannot hold the main thread, and
  /// well over what pressing a banner button needs.
  static let readTimeout: Float = 0.5
  /// How long a banner may go unreadable before it is written off. Long enough to sit out any
  /// stall worth waiting for, short enough that a wedged Notification Center cannot strand a card.
  static let unknownGrace: TimeInterval = 5
}

private enum WindowKind {
  case banners([AXUIElement])
  case empty
  /// The window itself is gone.
  case dead
  /// The tree could not be read. Nothing may be concluded from it — least of all that the window
  /// is empty, which is the one conclusion that would put a live banner back on screen.
  case unreadable(String)
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
  /// When each parked window was first seen without banners; the grace period runs from here.
  private var emptySince = [AXUIElement: Date]()
  /// Where a revealed window is being held instead of off-screen: the spot its card was using.
  private var holdTargets = [AXUIElement: CGPoint]()
  private var loggedSkips = Set<AXUIElement>()
  private var unreadableWindows = Set<AXUIElement>()
  private var seenKeys = [String: Date]()
  private var liveKeys = Set<String>()
  /// The banner element behind each live key. A banner missing from the tree is asked directly
  /// whether it is still there before it is called gone.
  private var liveBanners = [String: AXUIElement]()
  private var bannerKeys = [AXUIElement: String]()
  /// The window each live banner was last seen in, so an empty-looking window is not put back
  /// while a banner it was holding still answers for itself.
  private var bannerWindow = [String: AXUIElement]()
  private var observedBanners = Set<AXUIElement>()
  /// Keys the tree has lost sight of but whose banners still answer; logged once, not every scan.
  private var heldKeys = Set<String>()
  /// When each of those was last seen in the tree. Still answering is proof of life and waits as
  /// long as it likes; a banner we simply cannot read does not get to wait forever.
  private var heldSince = [String: Date]()
  private var lastReadFailureLog = Date.distantPast
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
    // Cut a read that is going nowhere short instead of letting it hold the main thread: a blocked
    // main thread stops the hold timer and a parked banner walks back on screen. A read that times
    // out now says so, and a read that says nothing changes nothing.
    AXUIElementSetMessagingTimeout(element, K.readTimeout)
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
    observedBanners.removeAll()
    loggedSkips.removeAll()
    unreadableWindows.removeAll()
    emptySince.removeAll()
    holdTargets.removeAll()
    releasedWindows.removeAll()
    seenKeys.removeAll()
    liveKeys.removeAll()
    liveBanners.removeAll()
    bannerKeys.removeAll()
    bannerWindow.removeAll()
    heldKeys.removeAll()
    heldSince.removeAll()
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

  /// Bring the window holding this banner into view, centred on `card` (the card's rectangle in AX
  /// coordinates). Pressing a banner button can open something the system draws inside its own
  /// banner — a reply field, a menu — and the only way to use that is to look at the real thing,
  /// so it comes to where the card was standing, wherever that was.
  func reveal(_ banner: AXUIElement, in card: CGRect?) {
    for w in Array(parkedOrigins.keys) {
      releasedWindows.insert(w)
      emptySince.removeValue(forKey: w)
      guard let card, let bannerFrame = banner.frame(), let windowFrame = w.frame() else {
        restore(w, reason: "revealed")
        continue
      }
      // Centred on the card, then pulled back inside the display it landed on: a card in a corner
      // would otherwise centre a wider banner half off the screen.
      var wanted = CGRect(x: card.midX - bannerFrame.width / 2,
                          y: card.midY - bannerFrame.height / 2,
                          width: bannerFrame.width, height: bannerFrame.height)
      wanted = Self.keptOnScreen(wanted)
      let origin = CGPoint(x: wanted.minX - (bannerFrame.minX - windowFrame.minX),
                           y: wanted.minY - (bannerFrame.minY - windowFrame.minY))
      holdTargets[w] = origin
      let r = w.setPosition(origin)
      logI("reveal banner \(NSStringFromRect(wanted)) on card \(NSStringFromRect(card)) result=\(r.name)")
    }
  }

  /// Pushes a rectangle back inside the display it sits on, leaving a small margin.
  private static func keptOnScreen(_ frame: CGRect, margin: CGFloat = 8) -> CGRect {
    var id = CGDirectDisplayID(0)
    var count: UInt32 = 0
    guard CGGetDisplaysWithPoint(CGPoint(x: frame.midX, y: frame.midY), 1, &id, &count) == .success,
          count > 0, id != 0 else { return frame }
    let bounds = CGDisplayBounds(id)
    var out = frame
    out.origin.x = min(max(out.minX, bounds.minX + margin), max(bounds.minX, bounds.maxX - out.width - margin))
    out.origin.y = min(max(out.minY, bounds.minY + margin), max(bounds.minY, bounds.maxY - out.height - margin))
    return out
  }

  func restoreAll() {
    for (w, origin) in parkedOrigins {
      let r = w.setPosition(origin)
      logD("restore all result=\(r.name)")
    }
    parkedOrigins.removeAll()
    emptySince.removeAll()
    holdTargets.removeAll()
  }


  // MARK: events

  fileprivate func handle(_ notification: String, _ element: AXUIElement) {
    logD("event \(notification) on \(element.role ?? "?")[\(element.subrole ?? "-")]")
    if notification == kAXWindowCreatedNotification as String { observe(window: element) }
    if notification == kAXUIElementDestroyedNotification as String {
      // The system saying so is the one unarguable proof that a banner is finished.
      if let key = bannerKeys[element] { fireGone(key, reason: "destroyed") }
      releasedWindows.remove(element)
      emptySince.removeValue(forKey: element)
      holdTargets.removeValue(forKey: element)
      unreadableWindows.remove(element)
      if parkedOrigins.removeValue(forKey: element) != nil { observedWindows.remove(element) }
    }
    scan()
  }

  /// An unanswered read here is not an empty Notification Center: it returns nothing and this scan
  /// simply does nothing, leaving every window parked exactly where it was.
  private func windows() -> [AXUIElement] {
    guard let app = appElement else { return [] }
    switch app.read(kAXWindowsAttribute, as: [AXUIElement].self) {
    case .ok(let ws): return ws
    case .absent: return []
    case .dead: return []
    case .unknown(let e):
      logRead("window list: \(e.name)")
      return []
    }
  }

  /// Reads that did not happen are worth knowing about but come back twenty times a second;
  /// one line a second is enough to see them in the log.
  private func logRead(_ what: String) {
    guard Date().timeIntervalSince(lastReadFailureLog) > 1 else { return }
    lastReadFailureLog = Date()
    logD("read failed: \(what)")
  }

  /// Ask the banner itself to tell us when it dies, rather than inferring it from the tree.
  private func observe(banner: AXUIElement) {
    guard observedBanners.insert(banner).inserted else { return }
    register(kAXUIElementDestroyedNotification, on: banner, label: "banner")
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
        unreadableWindows.remove(w)
        if loggedSkips.insert(w).inserted { logD("skip window: \(why)") }
      case .unreadable(let why):
        // A tree we could not read tells us nothing. The window stays where it is — parked windows
        // parked, cards standing — until a read comes back that we can believe.
        emptySince.removeValue(forKey: w)
        if unreadableWindows.insert(w).inserted { logD("window unreadable: \(why)") }
      case .dead:
        unreadableWindows.remove(w)
        emptySince.removeValue(forKey: w)
        holdTargets.removeValue(forKey: w)
        releasedWindows.remove(w)
        if parkedOrigins.removeValue(forKey: w) != nil { observedWindows.remove(w) }
      case .empty:
        unreadableWindows.remove(w)
        releasedWindows.remove(w)
        // Accessibility drops the banner before its fade-out has finished drawing, so hold the
        // window off-screen a moment longer and let the animation play out where it cannot be seen.
        if parkedOrigins[w] == nil { break }
        // An empty tree is not an empty screen. While a banner this window was holding still
        // answers for itself, the window keeps standing where it cannot be seen: putting it back
        // now would drop a live banner — a persistent alert above all, which never leaves on its
        // own — into the corner of the screen for the user to find.
        if liveKeys.contains(where: { bannerWindow[$0] == w }) {
          emptySince.removeValue(forKey: w)
          break
        }
        let emptyAt = emptySince[w] ?? Date()
        emptySince[w] = emptyAt
        if Date().timeIntervalSince(emptyAt) >= K.emptyGrace {
          emptySince.removeValue(forKey: w)
          restore(w, reason: "no banner")
        }
      case .banners(let banners):
        unreadableWindows.remove(w)
        emptySince.removeValue(forKey: w)
        if banners.contains(where: isPermissionPrompt) {
          // macOS asking "‘App’ 알림 허용?" lives here too. It must stay where its buttons can be pressed.
          releasedWindows.remove(w)
          restore(w, reason: "permission prompt")
          continue
        }
        // The window's own top-left, before parking moved it away, names the display the banner is on.
        let originForScreen = parkedOrigins[w] ?? w.frame()?.origin
        park(w)
        let screenNumber = originForScreen.flatMap(displayID(forAXPoint:)) ?? 0
        for b in banners {
          // A banner already on a card is not read again. Reading walks its whole tree and looks up
          // an icon, and the hold timer comes back here twenty times a second. Worse, a banner being
          // taken apart answers with its text gone and its app name still carrying the title
          // ("카카오톡 오중석"), and that name then goes looking for an app that does not exist.
          if let live = liveKey(of: b) {
            present.insert(live)
            seenKeys[live] = Date()
            track(live, banner: b, in: w)
            continue
          }
          guard var notice = extract(b) else {
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
          notice.screenNumber = screenNumber
          let key = notice.key
          present.insert(key)
          track(key, banner: b, in: w)
          let now = Date()
          if liveKeys.contains(key) { seenKeys[key] = now; continue }
          if let t = seenKeys[key], now.timeIntervalSince(t) < 60 { continue }
          seenKeys[key] = now
          logI("notice app=\"\(notice.app)\" title=\"\(notice.title)\" alert=\(notice.isAlert) " +
               "actions=[\(notice.actions.map(\.label).joined(separator: ","))] key=\(key.prefix(8))")
          onNotice?(notice)
        }
      }
    }
    // Banners that were live a moment ago and are not in the tree now. Missing from the tree is
    // not proof of anything: Notification Center re-lays its stack out and a banner can drop out of
    // the tree for a moment while it is still drawn. Only the banner itself settles it.
    for key in liveKeys.subtracting(present) {
      guard let banner = liveBanners[key] else {
        fireGone(key, reason: "untracked")
        continue
      }
      switch banner.liveness {
      case .dead:
        fireGone(key, reason: "gone from tree, element dead")
      case .unknown(let e):
        // Not knowing is a state, not an answer, and it may not become a permanent one.
        let since = heldSince[key] ?? Date()
        heldSince[key] = since
        if heldKeys.insert(key).inserted { logD("hold \(key.prefix(8)): read failed (\(e.name))") }
        if Date().timeIntervalSince(since) >= K.unknownGrace {
          fireGone(key, reason: "unreadable for \(Int(K.unknownGrace))s (\(e.name))")
        } else {
          present.insert(key)
        }
      case .ok, .absent:
        heldSince[key] = Date()
        if heldKeys.insert(key).inserted { logD("hold \(key.prefix(8)): out of tree, still answering") }
        present.insert(key)
      }
    }
    liveKeys = present
    let cutoff = Date().addingTimeInterval(-120)
    seenKeys = seenKeys.filter { $0.value > cutoff }
  }

  /// Remember the banner behind a key: the handle it is asked through when the tree stops showing
  /// it, the window it belongs to, and a subscription to its death.
  private func track(_ key: String, banner: AXUIElement, in window: AXUIElement) {
    bannerWindow[key] = window
    if liveBanners[key] != banner {
      if let old = liveBanners[key] { bannerKeys.removeValue(forKey: old) }
      liveBanners[key] = banner
      bannerKeys[banner] = key
    }
    observe(banner: banner)
    heldKeys.remove(key)
    heldSince.removeValue(forKey: key)
  }

  /// The one place a banner is declared finished, with the reason that settled it. Everything a
  /// card outlives — the window coming back, the card going — hangs off this, so the log says why.
  private func fireGone(_ key: String, reason: String) {
    guard liveKeys.remove(key) != nil else { return }
    logD("gone \(key.prefix(8)) reason=\(reason)")
    forget(key)
    onGone?(key)
  }

  private func forget(_ key: String) {
    if let banner = liveBanners.removeValue(forKey: key) {
      bannerKeys.removeValue(forKey: banner)
      if observedBanners.remove(banner) != nil, let obs = observer {
        AXObserverRemoveNotification(obs, banner, kAXUIElementDestroyedNotification as CFString)
      }
    }
    bannerWindow.removeValue(forKey: key)
    heldKeys.remove(key)
    heldSince.removeValue(forKey: key)
  }

  /// The key of a banner that is already on a card, taken from the banner's own identifier so the
  /// rest of it can be left alone.
  private func liveKey(of banner: AXUIElement) -> String? {
    let id = (banner.identifier ?? "").uppercased()
    guard id.count == 36, liveKeys.contains(id) else { return nil }
    return id
  }

  private func classify(_ root: AXUIElement) -> WindowKind {
    var pending = [root]
    var visited = Set<AXUIElement>()
    var banners: [AXUIElement] = []
    var hasWidget = false
    // A read that did not happen leaves the walk half done. Whatever banners it did find still get
    // the window parked — hiding one banner too many costs nothing — but a tree we never finished
    // reading may never be called empty.
    func giveUp(_ why: String) -> WindowKind {
      banners.isEmpty ? .unreadable(why) : .banners(banners)
    }
    while let el = pending.popLast() {
      guard visited.insert(el).inserted else { continue }
      if visited.count > K.maxNodes { return .skip("too many nodes") }
      switch el.read(kAXIdentifierAttribute, as: String.self) {
      case .ok(let id):
        // The Notification Center panel (clock click) lists old notifications; leave it alone.
        if id == K.widgetEditorButton { return .skip("notification center panel") }
        if id.hasPrefix(K.widgetPrefix) { hasWidget = true }
      case .absent: break
      case .dead:
        if el == root { return .dead }
        continue
      case .unknown(let e): return giveUp("id: \(e.name)")
      }
      switch el.read(kAXSubroleAttribute, as: String.self) {
      case .ok(let sub) where K.bannerSubroles.contains(sub):
        banners.append(el)
        continue
      case .ok, .absent: break
      case .dead:
        if el == root { return .dead }
        continue
      case .unknown(let e): return giveUp("subrole: \(e.name)")
      }
      switch el.childList() {
      case .ok(let kids): pending.append(contentsOf: kids.reversed())
      case .absent: break
      case .dead:
        if el == root { return .dead }
        continue
      case .unknown(let e): return giveUp("children: \(e.name)")
      }
    }
    // A window that holds banners is a banner window even if desktop widgets share it.
    if !banners.isEmpty { return .banners(banners) }
    return hasWidget ? .skip("desktop widget") : .empty
  }

  // MARK: park / restore

  /// The display containing a point given in AX/CoreGraphics global coordinates (top-left origin).
  private func displayID(forAXPoint p: CGPoint) -> UInt32? {
    var id = CGDirectDisplayID(0)
    var count: UInt32 = 0
    let nudged = CGPoint(x: p.x + 10, y: p.y + 10)
    guard CGGetDisplaysWithPoint(nudged, 1, &id, &count) == .success, count > 0, id != 0 else { return nil }
    return id
  }

  private func park(_ window: AXUIElement) {
    guard !releasedWindows.contains(window) else { return }
    if parkedOrigins[window] == nil {
      guard let frame = window.frame() else { return }
      // The baseline is where the window belongs, and a window already off-screen is not there.
      // Taking a parked spot for home would make every later park push it further out and every
      // restore put it back out of sight, stranding the banner for good.
      if frame.minY <= -K.parkOffset / 2 {
        logE("baseline refused at \(NSStringFromRect(frame)); bringing the window back first")
        _ = window.setPosition(CGPoint(x: frame.minX, y: frame.minY + K.parkOffset))
        return
      }
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
    // A revealed window is held on its card's spot instead of off-screen, so the system's own
    // reply field stays where the user is looking even if Notification Center re-lays it out.
    let target = holdTargets[window] ?? CGPoint(x: origin.x, y: origin.y - K.parkOffset)
    if !force {
      switch window.readPoint() {
      case .dead:
        parkedOrigins.removeValue(forKey: window)
        holdTargets.removeValue(forKey: window)
        logD("parked window gone")
        return
      case .unknown(let e):
        // Not knowing where the window is says nothing about whether it is still ours. Dropping the
        // baseline here would hand the next park a parked spot to call home.
        logRead("hold position: \(e.name)")
        return
      case .absent:
        return
      case .ok(let current):
        if abs(current.y - target.y) < 1 { return }
        logD("snapped back to \(NSStringFromPoint(current)); re-parking")
      }
    }
    let r = window.setPosition(target)
    logD("park result=\(r.name)")
  }

  private func restore(_ window: AXUIElement, reason: String) {
    holdTargets.removeValue(forKey: window)
    guard let origin = parkedOrigins[window] else { return }
    let r = window.setPosition(origin)
    logD("restore reason=\(reason) result=\(r.name)")
    if r == .success || r == .invalidUIElement { parkedOrigins.removeValue(forKey: window) }
  }

  // MARK: content

  /// iPhone Mirroring appends a handoff line ("iPhone에서 가져옴" / "from your iPhone") to the banner.
  /// It marks a notification relayed from the phone, a different source than the same app on this Mac.
  private static let iPhoneHandoffMarkers = ["iPhone에서 가져옴", "from your iPhone", "from iPhone", "iPhone에서"]

  private func extract(_ banner: AXUIElement) -> Notice? {
    let carriesImage = banner.firstImage() != nil
    if carriesImage { logD("banner carries an image") }
    if dumpedBanners < 3 {
      dumpedBanners += 1
      var lines: [String] = []
      banner.dump(into: &lines)
      logD("banner tree:\n" + lines.joined(separator: "\n"))
    }
    logD("banner actions raw: \(banner.actions())")
    var fields = [String: String]()
    var others: [String] = []
    collectTexts(banner, depth: 0, fields: &fields, others: &others)

    // A notification relayed from the mirrored iPhone. Drop the handoff text so it never shows in the card.
    func isHandoff(_ s: String) -> Bool { Self.iPhoneHandoffMarkers.contains { s.localizedCaseInsensitiveContains($0) } }
    let descRaw = cleanAX(banner.desc ?? banner.attributedDescription ?? "")
    let fromIPhone = isHandoff(descRaw)
    if fromIPhone {
      others.removeAll(where: isHandoff)
      for (k, v) in fields where isHandoff(v) { fields[k] = nil }
    }

    var title = fields["title"] ?? others.first ?? ""
    let subtitle = fields["subtitle"] ?? ""
    let body = fields["body"] ?? (fields["title"] == nil ? others.dropFirst().joined(separator: "\n") : others.joined(separator: "\n"))
    // The banner's description reads "<app name> <title>, <subtitle>, <body>".
    let desc = cleanAX(banner.desc ?? banner.attributedDescription ?? "")
    var app = cleanAX(desc.components(separatedBy: ", ").first ?? desc)
    if !title.isEmpty, app.hasSuffix(title) { app = cleanAX(String(app.dropLast(title.count))) }
    // Some senders carry no app name in the description (phone notifications without a title, for one):
    // the first part is just the title. Then that is the name to show, and the title line stays empty.
    // A banner being taken apart still answers with its description after its text has gone. What
    // comes back then is a wordless card whose app name has the title run into it, so it is not a
    // notice at all — and the name it carries would send the icon lookup off to Spotlight.
    guard !title.isEmpty || !subtitle.isEmpty || !body.isEmpty else { return nil }
    if app.isEmpty, !title.isEmpty {
      logI("no app name in \"\(desc.prefix(80))\"; showing the title as the sender")
      app = title
      title = ""
    }
    let uuid = (banner.identifier ?? "").uppercased()
    return Notice(app: app, title: title, subtitle: subtitle, body: body,
                  isAlert: banner.subrole == "AXNotificationCenterAlert",
                  element: banner, uuid: uuid.count == 36 ? uuid : "",
                  icon: fromIPhone ? AppIcons.iPhoneImage : AppIcons.shared.icon(named: app),
                  actions: banner.customActions(), hasImage: carriesImage, fromIPhone: fromIPhone)
  }

  /// The permission request describes itself as "‘<app>’ 알림 경고" and offers 허용 / 허용 안 함.
  private func isPermissionPrompt(_ banner: AXUIElement) -> Bool {
    let desc = cleanAX(banner.desc ?? banner.attributedDescription ?? "")
    if Self.quotedName(desc) != nil { return true }
    return banner.customActions().contains { ["허용", "Allow"].contains($0.label) }
  }

  private static func quotedName(_ s: String) -> String? {
    let opens: Set<Character> = ["‘", "“", "'", "\""]
    let closes: Set<Character> = ["’", "”", "'", "\""]
    guard let first = s.first, opens.contains(first) else { return nil }
    let rest = s.dropFirst()
    guard let end = rest.firstIndex(where: { closes.contains($0) }) else { return nil }
    let name = rest[..<end].trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? nil : name
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

/// Finds apps by the name the banner shows (localized display name, e.g. "스크립트 편집기").
final class AppIcons {
  static let shared = AppIcons()
  /// Read on the main thread, written on `queue`.
  private let lock = NSLock()
  private var pathByName = [String: String]()
  private var missed = Set<String>()
  private var looking = Set<String>()
  private var scanned = false
  /// Everything that touches the disk — the folder index, Spotlight — runs here and never on the
  /// main thread. A blocked main thread stops the hold timer, and a parked banner walks back on
  /// screen while it is stopped.
  private let queue = DispatchQueue(label: "pounce.appicons", qos: .utility)

  /// The app's real icon, or a picture of where the notification came from: an iPhone for an app that
  /// only exists on the mirrored phone, this Mac for a Mac-side sender without an icon.
  /// Answers at once, always: a name that is not in the index is chased on `queue` and this
  /// notification shows the stand-in. The next one from the same app has the real icon.
  func icon(named name: String) -> NSImage? {
    guard !name.isEmpty else { return Self.standIn }
    if let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) {
      return running.icon ?? Self.macImage
    }
    if let path = cachedPath(named: name) { return NSWorkspace.shared.icon(forFile: path) }
    look(for: name)
    return Self.standIn
  }

  /// What stands in for an app with no icon here: an iPhone when the phone is mirrored to this Mac,
  /// this Mac otherwise.
  static var standIn: NSImage? { hasIPhoneMirroring ? iPhoneImage : macImage }

  /// Builds the folder index in the background at launch, so the first notification finds it ready.
  func warm() { queue.async { self.buildIndex() } }

  /// This Mac as the system draws it (About This Mac, Finder sidebar): the right model, automatically.
  static let macImage: NSImage? = NSImage(named: NSImage.computerName)

  /// An iPhone as Apple renders it. ProductKitCore carries product images by model; current models look
  /// alike from the front, so iPhone Air stands in for whatever is mirrored. The renders sit small inside
  /// a wide canvas, so they are trimmed to the phone. If the framework changes, a drawn phone takes over.
  static let iPhoneImage: NSImage? = {
    let productKit = Bundle(path: "/System/Library/PrivateFrameworks/ProductKitCore.framework")
    for name in ["iPhoneAir", "iPhone17", "iPhone16Pro"] {
      if let image = productKit?.image(forResource: NSImage.Name(name)) { return trimmed(image) }
    }
    return drawnIPhone(size: 256)
  }()

  /// The image cut down to its opaque pixels, from its largest representation.
  private static func trimmed(_ image: NSImage) -> NSImage {
    guard let rep = image.representations.max(by: { $0.pixelsWide < $1.pixelsWide }),
          let cg = rep.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8,
                              bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    guard let data = ctx.data else { return image }
    let px = data.bindMemory(to: UInt8.self, capacity: cg.width * cg.height * 4)
    var minX = cg.width, minY = cg.height, maxX = -1, maxY = -1
    for y in 0..<cg.height {
      for x in 0..<cg.width where px[(y * cg.width + x) * 4 + 3] > 8 {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
      }
    }
    guard maxX >= minX, maxY >= minY,
          let cropped = cg.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    else { return image }
    return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
  }

  /// A current iPhone from the front: thin bezel, Dynamic Island, the blue screen of the system's device icons.
  private static func drawnIPhone(size s: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
      let h = s * 0.92, w = h / 2.05
      let body = NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h)
      let bodyR = w * 0.17
      let bodyPath = NSBezierPath(roundedRect: body, xRadius: bodyR, yRadius: bodyR)
      NSGradient(colors: [NSColor(calibratedWhite: 0.30, alpha: 1), NSColor(calibratedWhite: 0.10, alpha: 1),
                          NSColor(calibratedWhite: 0.22, alpha: 1)])!.draw(in: bodyPath, angle: -60)
      NSColor(calibratedWhite: 0.55, alpha: 0.9).setStroke()
      bodyPath.lineWidth = max(1, s * 0.006)
      bodyPath.stroke()
      let bezel = w * 0.035
      let screen = body.insetBy(dx: bezel, dy: bezel)
      let screenPath = NSBezierPath(roundedRect: screen, xRadius: bodyR - bezel, yRadius: bodyR - bezel)
      NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.66, blue: 0.98, alpha: 1),
                          NSColor(calibratedRed: 0.20, green: 0.48, blue: 0.92, alpha: 1)])!.draw(in: screenPath, angle: -90)
      let islandW = screen.width * 0.30, islandH = screen.width * 0.085
      NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
      NSBezierPath(roundedRect: NSRect(x: screen.midX - islandW / 2, y: screen.maxY - screen.width * 0.06 - islandH,
                                       width: islandW, height: islandH),
                   xRadius: islandH / 2, yRadius: islandH / 2).fill()
      NSColor(calibratedWhite: 0.40, alpha: 1).setFill()
      let bw = max(1, w * 0.02)
      for (y, len) in [(0.80, 0.045), (0.70, 0.085), (0.60, 0.085)] {
        NSRect(x: body.minX - bw, y: body.minY + h * CGFloat(y), width: bw, height: h * CGFloat(len)).fill()
      }
      NSRect(x: body.maxX, y: body.minY + h * 0.66, width: bw, height: h * 0.12).fill()
      return true
    }
  }

  /// iPhone Mirroring has been set up on this Mac, so a sender that is not a Mac app is most likely a phone app.
  static let hasIPhoneMirroring =
    FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Containers/com.apple.ScreenContinuity")

  /// The app's bundle, once it is known. Hands the answer back on the main thread — straight from
  /// the index, or after the lookup for a name that is not in it.
  func findPath(named name: String, then handle: @escaping (String?) -> Void) {
    if let path = cachedPath(named: name) { handle(path); return }
    queue.async {
      self.buildIndex()
      let path = self.resolve(name)
      DispatchQueue.main.async { handle(path) }
    }
  }

  private func cachedPath(named name: String) -> String? {
    lock.lock()
    defer { lock.unlock() }
    return pathByName[name]
  }

  /// Asks the disk once per name and remembers the answer, a miss included. Runs on `queue`.
  @discardableResult private func resolve(_ name: String) -> String? {
    lock.lock()
    let known = pathByName[name]
    let alreadyMissed = missed.contains(name)
    lock.unlock()
    defer {
      lock.lock()
      looking.remove(name)
      lock.unlock()
    }
    if let known { return known }
    guard !alreadyMissed else { return nil }
    let found = spotlight(named: name)
    lock.lock()
    if let found { pathByName[name] = found } else { missed.insert(name) }
    lock.unlock()
    if found == nil { logD("app icon: no app named \"\(name)\"") }
    return found
  }

  /// One lookup per name: notifications arriving while it runs do not pile more on.
  private func look(for name: String) {
    lock.lock()
    let known = missed.contains(name) || looking.contains(name)
    if !known { looking.insert(name) }
    lock.unlock()
    guard !known else { return }
    queue.async {
      self.buildIndex()
      self.resolve(name)
    }
  }

  /// Standard app folders plus one level of vendor subfolders (e.g. /Applications/Utilities, ~/Applications/JetBrains).
  /// Walks the disk, so it is only ever called on `queue`. Runs once.
  private func buildIndex() {
    lock.lock()
    let done = scanned
    scanned = true
    lock.unlock()
    guard !done else { return }
    let fm = FileManager.default
    let roots = ["/Applications", NSHomeDirectory() + "/Applications",
                 "/System/Applications", "/System/Library/CoreServices"]
    var found = [String: String]()
    for root in roots {
      for entry in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
        let path = "\(root)/\(entry)"
        if entry.hasSuffix(".app") { register(path, into: &found); continue }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
        for sub in (try? fm.contentsOfDirectory(atPath: path)) ?? [] where sub.hasSuffix(".app") {
          register("\(path)/\(sub)", into: &found)
        }
      }
    }
    lock.lock()
    for (name, path) in found where pathByName[name] == nil { pathByName[name] = path }
    let count = pathByName.count
    lock.unlock()
    logD("app icon index: \(count) names")
  }

  /// One bundle answers to several names: file name, Finder display name, CFBundleDisplayName / CFBundleName
  /// in the current language and in the base Info.plist.
  private func register(_ path: String, into index: inout [String: String]) {
    let fm = FileManager.default
    var names = [String((path as NSString).lastPathComponent.dropLast(4))]
    var display = fm.displayName(atPath: path)
    if display.hasSuffix(".app") { display = String(display.dropLast(4)) }
    names.append(display)
    if let bundle = Bundle(path: path) {
      for dict in [bundle.localizedInfoDictionary, bundle.infoDictionary] {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
          if let n = dict?[key] as? String { names.append(n) }
        }
      }
    }
    for n in names where !n.isEmpty && index[n] == nil { index[n] = path }
  }

  /// Apps installed anywhere else: ask Spotlight once per name. Blocks, so it stays on `queue`.
  private func spotlight(named name: String) -> String? {
    let q = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
    task.arguments = ["kMDItemContentType == 'com.apple.application-bundle' && (kMDItemDisplayName == '\(q)' || kMDItemFSName == '\(q).app')"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    do { try task.run() } catch { return nil }
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    task.waitUntilExit()
    return out.split(separator: "\n").map(String.init).first { $0.hasSuffix(".app") }
  }
}
