import AppKit
import ApplicationServices
import ServiceManagement
import UserNotifications

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
    openLog: { [weak self] in self?.openLog() },
    quit: { [weak self] in self?.quit() }))
  private var trustTimer: Timer?
  private var termSources: [DispatchSourceSignal] = []

  func applicationDidFinishLaunching(_: Notification) {
    logI("launch \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "")")
    setupStatusItem()
    installMainMenu()
    Settings.shared.onMenuBarChange = { [weak self] in self?.applyMenuBarVisibility() }
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
    let sound = Settings.shared.sound
    if !sound.isEmpty { NSSound(named: sound)?.play() }
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
    item.isVisible = !Settings.shared.menuBarHidden
    statusItem = item
  }

  /// A Pounce-branded test notice, built right here so it carries the app's own icon and name,
  /// exactly like the pinned test. Nothing goes through macOS, so no permission is needed.
  private func testNotice(_ title: String, _ body: String, alert: Bool) -> Notice {
    Notice(app: "Pounce", title: title, subtitle: "", body: body,
           isAlert: alert, element: nil, uuid: UUID().uuidString,
           icon: NSApp.applicationIconImage, actions: [])
  }

  @objc private func sendTest() {
    sendNotification("테스트 알림", "알림이 화면 가운데에 표시됩니다.")
  }

  /// Five in a row, 1.2 s apart: they share the app, so they stack into one card.
  @objc private func sendFiveTests() {
    for i in 1...5 {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 1.2) { [weak self] in
        self?.sendNotification("테스트 알림 \(i)/5", "연속으로 온 알림은 카드 하나에 묶입니다.")
      }
    }
  }

  /// The real way: the app posts a notification under its own name, so the banner is Pounce's and
  /// our watcher intercepts it into a card with the app's icon. If notifications are off, we build the
  /// card directly so the test still works.
  private func sendNotification(_ title: String, _ body: String) {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.getNotificationSettings { settings in
      let post = {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil   // the card plays the chosen sound when it appears; no double
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(req) { error in if let error { logE("post notification: \(error)") } }
      }
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        DispatchQueue.main.async(execute: post)
      case .notDetermined:
        center.requestAuthorization(options: [.alert]) { granted, _ in
          DispatchQueue.main.async {
            if granted { post() } else { self.present(self.testNotice(title, body, alert: false), via: "test") }
          }
        }
      default:
        // Notifications denied for this app: fall back to a directly built card.
        DispatchQueue.main.async { self.present(self.testNotice(title, body, alert: false), via: "test") }
      }
    }
  }

  /// A card that stays until closed, the way a persistent alert does.
  @objc private func sendPinnedTest() {
    present(testNotice("고정 알림", "닫을 때까지 남습니다.", alert: true), via: "test")
  }

  @objc private func dismissAll() { cards.dismissAll() }

  /// The same paw as the app icon, as a template so the menu bar tints it for light, dark and accents.
  private static func menuBarPaw() -> NSImage? {
    guard let path = Bundle.main.path(forResource: "paw", ofType: "png"), let paw = NSImage(contentsOfFile: path) else {
      return NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pounce")
    }
    paw.isTemplate = true
    paw.size = NSSize(width: 18, height: 18)
    paw.accessibilityDescription = "Pounce"
    return paw
  }

  @objc private func openSettings() { settingsWindow.show() }

  @objc private func screensChanged() { cards.layout() }

  @objc private func openLog() { NSWorkspace.shared.open(Log.shared.url) }

  @objc private func quit() { NSApp.terminate(nil) }

  private func applyMenuBarVisibility() {
    statusItem?.isVisible = !Settings.shared.menuBarHidden
  }

  /// Launching the app while it already runs (Launchpad, Spotlight, `open -a`) lands here: the way back
  /// to Settings when the paw is hidden.
  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
    settingsWindow.show()
    return false
  }

  /// No visible menu bar of its own (LSUIElement), but ⌘Q and ⌘W still work while the settings window is up.
  private func installMainMenu() {
    let app = NSMenuItem()
    app.submenu = NSMenu()
    app.submenu?.addItem(withTitle: "Pounce 종료", action: #selector(quit), keyEquivalent: "q").target = self
    let window = NSMenuItem()
    window.submenu = NSMenu()
    window.submenu?.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    let main = NSMenu()
    main.items = [app, window]
    NSApp.mainMenu = main
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  /// Draw our own notifications as banners even though we run as an accessory, so the watcher can park them.
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list])
  }
}
