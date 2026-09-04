import AppKit
import ApplicationServices
import ServiceManagement

@main
struct Main {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let watcher = Watcher()
  private var seen = [String: Date]()
  private lazy var cards = CardManager(handlers: CardHandlers(
    activate: { notice in
      // Forward the click to the hidden system banner so the source app opens what it wanted.
      // Press the hidden banner so the app opens exactly what the notification pointed at.
      // If the banner is already gone, fall back to bringing the app forward or launching it.
      var pressed = false
      if let element = notice.element { pressed = element.press() == .success }
      logD("press original banner ok=\(pressed)")
      if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == notice.app }) {
        app.activate()
      } else if !pressed, let path = AppIcons.shared.path(named: notice.app) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init())
      }
    },
    action: { [weak self] notice, action in
      // A button may open inline UI (e.g. reply) inside the system banner, so show it again first.
      guard let element = notice.element else { return }
      self?.watcher.release(element)
      logD("action \"\(action.label)\" result=\(element.perform(action.name).name)")
    },
    close: { group in
      // Closing our card closes every system notification in the group, so alerts do not linger.
      for n in group.notices {
        if let element = n.element, let close = n.actions.first(where: \.isClose) {
          logD("close original result=\(element.perform(close.name).name)")
        }
      }
    }))
  private var statusItem: NSStatusItem?
  private lazy var settingsWindow = SettingsWindow(actions: SettingsActions(
    sendTest: { [weak self] in self?.sendTest() },
    sendFiveTests: { [weak self] in self?.sendFiveTests() },
    sendPinnedTest: { [weak self] in self?.sendPinnedTest() },
    dismissAll: { [weak self] in self?.dismissAll() },
    openLog: { [weak self] in self?.openLog() }))
  private var trustTimer: Timer?
  private var termSources: [DispatchSourceSignal] = []

  func applicationDidFinishLaunching(_: Notification) {
    logI("launch \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "")")
    setupStatusItem()
    Settings.shared.onChange = { [weak self] in self?.cards.layout() }
    Settings.shared.onSizeChange = { [weak self] in self?.cards.dismissAll() }
    NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                           name: NSApplication.didChangeScreenParametersNotification, object: nil)
    watcher.onNotice = { [weak self] notice in self?.present(notice, via: "ax") }
    watcher.onGone = { [weak self] key in self?.cards.remove(key: key) }
    watcher.onLostTrust = { [weak self] in self?.ensureTrustedThenStart() }
    let dnc = DistributedNotificationCenter.default()
    dnc.addObserver(self, selector: #selector(screenLocked), name: .init("com.apple.screenIsLocked"), object: nil)
    dnc.addObserver(self, selector: #selector(screenUnlocked), name: .init("com.apple.screenIsUnlocked"), object: nil)
    setupLoginItemOnFirstRun()
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(appLaunched(_:)),
      name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    ensureTrustedThenStart()
    installTerminationHandler()
  }

  /// `pkill` sends SIGTERM, which skips applicationWillTerminate; restore the system window first.
  private func installTerminationHandler() {
    for sig in [SIGTERM, SIGINT, SIGHUP] {
      signal(sig, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
      source.setEventHandler { [weak self] in
        self?.watcher.stop()
        logI("signal \(sig): restored and exiting")
        exit(0)
      }
      source.resume()
      termSources.append(source)
    }
  }

  func applicationWillTerminate(_: Notification) {
    watcher.stop()
    logI("quit")
  }

  @objc private func screenLocked() { watcher.isPaused = true }
  @objc private func screenUnlocked() { watcher.isPaused = false }

  /// A notification relocator that is not running does nothing, so it starts with the session.
  private func setupLoginItemOnFirstRun() {
    let key = "didSetupLoginItem"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    UserDefaults.standard.set(true, forKey: key)
    do {
      try SMAppService.mainApp.register()
      logI("login item registered on first run")
    } catch {
      logE("login item: \(error)")
    }
  }

  // MARK: permission

  private func ensureTrustedThenStart() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) {
      _ = watcher.start()
      return
    }
    logI("waiting for Accessibility permission")
    trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
      guard AXIsProcessTrusted() else { return }
      t.invalidate()
      self?.trustTimer = nil
      logI("Accessibility granted")
      _ = self?.watcher.start()
    }
  }

  @objc private func appLaunched(_ note: Notification) {
    guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
          app.bundleIdentifier == "com.apple.notificationcenterui" else { return }
    logI("Notification Center relaunched; re-attaching")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in _ = self?.watcher.start() }
  }

  // MARK: notices

  /// Both routes feed here; whichever reports a notification first wins.
  private func present(_ notice: Notice, via route: String) {
    let now = Date()
    seen = seen.filter { now.timeIntervalSince($0.value) < 120 }
    if let t = seen[notice.key], now.timeIntervalSince(t) < 60 {
      logD("duplicate via \(route): \(notice.title)")
      return
    }
    seen[notice.key] = now
    logI("show via \(route): \(notice.app) / \(notice.title)")
    cards.add(notice)
  }


  // MARK: menu

  private func setupStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = Self.menuBarPaw()
    let menu = NSMenu()
    menu.addItem(withTitle: "설정…", action: #selector(openSettings), keyEquivalent: ",")
    menu.addItem(withTitle: "닫기", action: #selector(quit), keyEquivalent: "q")
    for m in menu.items { m.target = self }
    item.menu = menu
    statusItem = item
  }

  @objc private func sendTest() {
    post(title: "테스트 알림", body: "알림이 화면 가운데에 표시됩니다.")
  }

  /// Five in a row, 1.2 s apart: fast enough to stack, slow enough that macOS draws every banner.
  @objc private func sendFiveTests() {
    for i in 1...5 {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 1.2) { [weak self] in
        self?.post(title: "테스트 알림 \(i)/5", body: "연속으로 온 알림은 카드 하나에 묶입니다.")
      }
    }
  }

  /// A card that stays until closed, the way a persistent alert does. Made right here, not sent
  /// through macOS, so it needs no notification permission and nothing else opens.
  @objc private func sendPinnedTest() {
    let notice = Notice(app: "CentreGrowl", title: "고정 알림", subtitle: "", body: "닫을 때까지 남습니다.",
                        isAlert: true, element: nil, uuid: UUID().uuidString,
                        icon: NSApp.applicationIconImage, actions: [])
    present(notice, via: "test")
  }

  private func post(title: String, subtitle: String = "", body: String) {
    func q(_ s: String) -> String { s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
    // "default" plays the alert sound the user chose in System Settings for this sender.
    var script = "display notification \"\(q(body))\" with title \"\(q(title))\""
    if !subtitle.isEmpty { script += " subtitle \"\(q(subtitle))\"" }
    script += " sound name \"default\""
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = ["-e", script]
    try? task.run()
  }

  @objc private func dismissAll() { cards.dismissAll() }

  /// The same paw as the app icon, as a template so the menu bar tints it for light, dark and accents.
  private static func menuBarPaw() -> NSImage? {
    guard let path = Bundle.main.path(forResource: "paw", ofType: "png"), let paw = NSImage(contentsOfFile: path) else {
      return NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "CentreGrowl")
    }
    paw.isTemplate = true
    paw.size = NSSize(width: 18, height: 18)
    paw.accessibilityDescription = "CentreGrowl"
    return paw
  }

  @objc private func openSettings() { settingsWindow.show() }

  @objc private func screensChanged() { cards.layout() }

  @objc private func openLog() { NSWorkspace.shared.open(Log.shared.url) }

  @objc private func quit() { NSApp.terminate(nil) }
}
