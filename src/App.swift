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
  private var trustTimer: Timer?
  private var termSources: [DispatchSourceSignal] = []

  func applicationDidFinishLaunching(_: Notification) {
    logI("launch \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "")")
    setupStatusItem()
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
    item.button?.image = NSImage(systemSymbolName: "bell.and.waves.left.and.right", accessibilityDescription: "CentreGrowl")
    let menu = NSMenu()
    menu.addItem(withTitle: "테스트 알림 보내기", action: #selector(sendTest), keyEquivalent: "t")
    menu.addItem(withTitle: "테스트 알림 5개 보내기", action: #selector(sendFiveTests), keyEquivalent: "5")
    menu.addItem(withTitle: "떠 있는 알림 테스트 (CentreGrowl 자체 알림)", action: #selector(sendAlertTest), keyEquivalent: "a")
    menu.addItem(withTitle: "모든 카드 닫기", action: #selector(dismissAll), keyEquivalent: "")
    menu.addItem(.separator())
    let login = NSMenuItem(title: "로그인 시 실행", action: #selector(toggleLogin), keyEquivalent: "")
    login.state = SMAppService.mainApp.status == .enabled ? .on : .off
    menu.addItem(login)
    let debug = NSMenuItem(title: "디버그 로그", action: #selector(toggleDebug), keyEquivalent: "")
    debug.state = Log.shared.debugEnabled ? .on : .off
    menu.addItem(debug)
    menu.addItem(withTitle: "로그 열기", action: #selector(openLog), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(withTitle: "종료", action: #selector(quit), keyEquivalent: "q")
    for m in menu.items { m.target = self }
    item.menu = menu
    statusItem = item
  }

  @objc private func sendTest() {
    post(title: "CentreGrowl", subtitle: "테스트", body: "정중앙에서 팍")
  }

  /// Five in a row, 1.2 s apart: fast enough to stack, slow enough that macOS draws every banner.
  @objc private func sendFiveTests() {
    for i in 1...5 {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 1.2) { [weak self] in
        self?.post(title: "테스트 알림 \(i)", subtitle: "5개 연속", body: "\(i) 번째 본문입니다")
      }
    }
  }

  /// Posts a notification from CentreGrowl itself. Whether it is a fleeting banner or a lingering
  /// alert is the user's choice in System Settings > Notifications > CentreGrowl, exactly as for any app.
  @objc private func sendAlertTest() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error { logE("notification auth: \(error)") }
      guard granted else {
        logI("notification auth denied")
        DispatchQueue.main.async { self.openNotificationSettings() }
        return
      }
      let content = UNMutableNotificationContent()
      content.title = "떠 있는 알림 테스트"
      content.subtitle = "CentreGrowl"
      content.body = "시스템 설정 > 알림 > CentreGrowl 의 스타일이 \"알림\" 이면 닫을 때까지 남고, \"배너\" 면 잠시 뒤 사라집니다."
      content.sound = .default
      let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
      center.add(req) { error in
        if let error { logE("notification add: \(error)") } else { logI("own test notification posted") }
      }
    }
  }

  @objc private func openNotificationSettings() {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
  }

  private func post(title: String, subtitle: String, body: String) {
    func q(_ s: String) -> String { s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
    // "default" plays the alert sound the user chose in System Settings for this sender.
    let script = "display notification \"\(q(body))\" with title \"\(q(title))\" subtitle \"\(q(subtitle))\" sound name \"default\""
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = ["-e", script]
    try? task.run()
  }

  @objc private func dismissAll() { cards.dismissAll() }

  @objc private func toggleLogin(_ sender: NSMenuItem) {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
        sender.state = .off
      } else {
        try SMAppService.mainApp.register()
        sender.state = .on
      }
    } catch {
      logE("login item: \(error)")
    }
  }

  @objc private func toggleDebug(_ sender: NSMenuItem) {
    let next = !Log.shared.debugEnabled
    UserDefaults.standard.set(next, forKey: "debugLoggingEnabled")
    sender.state = next ? .on : .off
  }

  @objc private func openLog() { NSWorkspace.shared.open(Log.shared.url) }

  @objc private func quit() { NSApp.terminate(nil) }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  /// Our own notifications must show even though we are the posting app.
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound])
  }
}
