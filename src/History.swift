import AppKit
import SQLite3

/// ⌘ 를 누른 채 휠을 굴리면 알림센터에 남아 있는 지난 알림을 카드로 한 장씩 넘겨 본다.
/// 목록을 스크롤하듯 넘긴다: 알림센터처럼 새것이 위, 오래된 것이 아래. 가장 새것에서 더 위로 가면
/// 닫힌다. 방향은 시스템의 스크롤 설정을 따른다.
/// 설정에서 켠 동안만 휠을 받는다.
///
/// 이벤트는 탭으로 받아 삼킨다. 전역 모니터는 보기만 해서, 포인터 아래 앱도 같은 휠을 받아
/// 확대되거나 스크롤된다.
final class HistoryWheel {
  private let cards: CardManager
  private var tap: CFMachPort?
  /// 이번에 넘겨 보는 목록. 다시 보기 카드가 사라지면 버리고, 다음에 다시 읽는다.
  private var notices: [Notice] = []
  private var index = -1
  /// 트랙패드는 조금씩 여러 번 온다. 모아서 한 칸이 되면 넘긴다.
  private var travel: Double = 0
  /// 이번 쓸기에서 이미 한 장 넘겼는지.
  private var stepped = false
  private static let stepTravel: Double = 60

  init(cards: CardManager) { self.cards = cards }

  /// 설정을 따라 켜고 끈다.
  func apply() {
    if Settings.shared.recallWheel { start() } else { stop() }
  }

  private func stop() {
    guard let port = tap else { return }
    CGEvent.tapEnable(tap: port, enable: false)
    CFMachPortInvalidate(port)
    tap = nil
    cards.endRecall()
    logI("history: ⌘+wheel off")
  }

  private func start() {
    guard tap == nil else { return }
    let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
    let me = Unmanaged.passUnretained(self).toOpaque()
    guard let port = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask, callback: { _, type, event, me in
        guard let me else { return Unmanaged.passUnretained(event) }
        let wheel = Unmanaged<HistoryWheel>.fromOpaque(me).takeUnretainedValue()
        return wheel.handle(type, event)
      }, userInfo: me)
    else {
      logE("history: event tap refused")
      return
    }
    tap = port
    let source = CFMachPortCreateRunLoopSource(nil, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)
    logI("history: ⌘+wheel on")
  }

  private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    // 탭이 느리다고 시스템이 꺼 버리면 다시 켠다.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let mods = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    guard type == .scrollWheel, mods == .maskCommand else { return Unmanaged.passUnretained(event) }
    // 매직 마우스·트랙패드는 손가락이 닿은 동안 조금씩 여러 번 온다. 손가락 한 번 쓸면 한 장이다 —
    // 모인 거리가 한 칸이 되면 넘기고, 그 쓸기의 나머지는 손을 떼고 다시 댈 때까지 버린다. 거리마다
    // 넘기면 길게 쓴 한 번이 두세 장을 건너뛴다. 손을 뗀 뒤 관성으로 오는 것은 삼키기만 한다.
    guard event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0 else { return nil }
    let dy: Double
    if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
      if event.getIntegerValueField(.scrollWheelEventScrollPhase) == Int64(NSEvent.Phase.began.rawValue) {
        travel = 0
        stepped = false
      }
      guard !stepped else { return nil }
      travel += event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
      guard abs(travel) >= Self.stepTravel else { return nil }
      dy = travel
      travel = 0
      stepped = true
    } else {
      dy = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
    }
    // 목록을 스크롤할 때와 같은 쪽으로 간다. 자연스러운 스크롤이면 손가락을 올릴 때 목록이 올라가
    // 아래의 오래된 것이 나온다. 알림센터처럼 새것이 위, 오래된 것이 아래다.
    if dy < 0 { older() } else if dy > 0 { newer() }
    return nil
  }

  private func older() {
    if !cards.isRecalling {
      guard let found = NotificationDB.read() else {
        NotificationDB.openSettings()
        return
      }
      notices = found
      // 떠 있던 알림 카드는 목록의 한 장이다 — 그 카드가 첫 장이면 그다음 장부터 보인다.
      if let shown = cards.newestShown,
         let at = found.firstIndex(where: { $0.title == shown.title && $0.body == shown.body }) {
        index = at
      } else {
        index = -1
      }
      show(index + 1, older: true)
      return
    }
    show(index + 1, older: true)
  }

  private func newer() {
    guard cards.isRecalling else { return }
    if index <= 0 {
      cards.endRecall(slide: true)
      return
    }
    show(index - 1, older: false)
  }

  private func show(_ i: Int, older: Bool) {
    guard notices.indices.contains(i) else {
      if notices.isEmpty { logI("history: nothing in Notification Center") }
      return
    }
    index = i
    var n = notices[i]
    n.arrived = Date()
    cards.recall(n, older: older)
  }
}

/// 알림센터가 쌓아 두는 기록. usernoted 의 SQLite 로, 알림센터에서 지운 것은 여기서도 빠진다.
/// 보호된 자리라 전체 디스크 접근 권한이 있어야 열린다.
enum NotificationDB {
  static let path = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path

  /// 권한이 있는지. 권한이 없으면 파일은 있어도 열리지 않는다.
  static var readable: Bool {
    let fd = open(path, O_RDONLY)
    guard fd >= 0 else { return false }
    close(fd)
    return true
  }

  private static var lastAsked = Date.distantPast

  /// 권한은 코드로 줄 수 없다. 설정의 전체 디스크 접근 목록을 연다. 휠은 한 번에 여러 칸 오므로
  /// 한 번 굴린 것에 창이 여러 번 뜨지 않게 한다.
  static func openSettings() {
    guard Date().timeIntervalSince(lastAsked) > 10 else { return }
    lastAsked = Date()
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
      NSWorkspace.shared.open(url)
    }
  }

  /// 새것부터 — 맥 앱 알림(DB)과 아이폰 미러링 알림(remote)을 시각으로 합친다. 권한이 없거나 열 수 없으면 nil.
  static func read(limit: Int = 200) -> [Notice]? {
    guard let mac = readMac(limit: limit) else { return nil }
    let all = (mac + readIPhone()).sorted { $0.date > $1.date }.prefix(limit).map(\.notice)
    logI("history: \(all.count) notices (mac \(mac.count))")
    logD("history newest: " + all.prefix(8).map { "\($0.fromIPhone ? "📱" : "💻")\($0.app): \($0.title.prefix(20))" }.joined(separator: " / "))
    return Array(all)
  }

  private typealias Dated = (date: Date, notice: Notice)

  private static func readMac(limit: Int) -> [Dated]? {
    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
      logE("history: cannot open the notification database (\(String(cString: sqlite3_errmsg(db))))")
      sqlite3_close(db)
      return nil
    }
    defer { sqlite3_close(db) }
    // 전달된 적 없는 것(예약만 된 요청, delivered_date 0)은 알림센터에 없다.
    let sql = """
      SELECT app.identifier, record.data, record.delivered_date FROM record
      JOIN app ON app.app_id = record.app_id
      WHERE record.delivered_date > 0
      ORDER BY record.delivered_date DESC LIMIT \(limit)
      """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      logE("history: query failed (\(String(cString: sqlite3_errmsg(db))))")
      return nil
    }
    defer { sqlite3_finalize(stmt) }
    var out: [Dated] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      let bundle = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
      let date = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, 2))
      guard let bytes = sqlite3_column_blob(stmt, 1) else { continue }
      let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, 1)))
      guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
      else { continue }
      let req = plist["req"] as? [String: Any] ?? [:]
      let title = cleanAX(req["titl"] as? String ?? "")
      let subtitle = cleanAX(req["subt"] as? String ?? "")
      let body = cleanAX(req["body"] as? String ?? "")
      guard !title.isEmpty || !subtitle.isEmpty || !body.isEmpty else { continue }
      let (name, icon) = app(bundle)
      out.append((date, Notice(app: name, title: title, subtitle: subtitle, body: body, isAlert: false,
                               element: nil, uuid: "", icon: icon, actions: [])))
    }
    return out
  }

  // MARK: 아이폰 미러링

  /// 미러링된 아이폰 알림은 DB 가 아니라 앱마다 따로 적힌다: Remote/default/<앱 UUID>/DeliveredNotifications.plist,
  /// 번들 ID ↔ 앱 UUID 표는 같은 자리의 Library.plist.
  private static let remote = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Group Containers/group.com.apple.UserNotifications/Library/UserNotifications/Remote/default").path

  private static func readIPhone() -> [Dated] {
    guard let data = FileManager.default.contents(atPath: remote + "/Library.plist") else {
      logD("history: no iPhone notification table (\(String(cString: strerror(errno))))")
      return []
    }
    // 키 아카이브(NSKeyedArchiver)로 적혀 있다.
    guard let table = unarchive(data) as? [String: String] else {
      logD("history: iPhone notification table unreadable")
      return []
    }
    var out: [Dated] = []
    for (bundle, folder) in table {
      guard let data = FileManager.default.contents(atPath: remote + "/" + folder + "/DeliveredNotifications.plist"),
            let items = unarchive(data) as? [[String: Any]] else { continue }
      for item in items {
        let title = cleanAX(item["AppNotificationTitle"] as? String ?? "")
        let subtitle = cleanAX(item["AppNotificationSubtitle"] as? String ?? "")
        let body = cleanAX(item["AppNotificationMessage"] as? String ?? "")
        guard !title.isEmpty || !subtitle.isEmpty || !body.isEmpty else { continue }
        let date = item["AppNotificationCreationDate"] as? Date ?? .distantPast
        out.append((date, Notice(app: IPhoneApps.name(bundle, title: title, body: body), title: title,
                                 subtitle: subtitle, body: body, isAlert: false, element: nil, uuid: "",
                                 icon: AppIcons.iPhoneImage, actions: [], fromIPhone: true)))
      }
    }
    return out
  }

  private static func unarchive(_ data: Data) -> Any? {
    guard let u = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
    u.requiresSecureCoding = false
    return u.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
  }

  /// 기록에는 번들 ID 만 있다. 카드에는 사람이 읽는 이름과 아이콘이 필요하다.
  private static func app(_ bundle: String) -> (String, NSImage?) {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
      return (bundle, AppIcons.shared.icon(named: bundle))
    }
    let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    return (name, NSWorkspace.shared.icon(forFile: url.path))
  }
}

/// 아이폰 앱의 이름. 미러링 기록에는 번들 ID 만 있고 표시 이름은 이 맥 어디에도 없다. 그래서 실제 배너가
/// 올 때(Watcher 가 읽은 앱 이름) 제목·본문을 적어 두었다가, 기록에서 같은 제목·본문을 가진 알림의 번들 ID 에
/// 그 이름을 붙여 기억한다. 아직 모르는 앱은 번들 ID 의 마지막 토막으로 대신한다.
enum IPhoneApps {
  private static let key = "iPhoneAppNames"
  /// 최근 아이폰 배너: 제목+본문 → 앱 이름. 실행 중에만 든다.
  private static var recent: [String: String] = [:]

  static func saw(_ notice: Notice) {
    guard notice.fromIPhone, !notice.app.isEmpty else { return }
    recent[match(notice.title, notice.body)] = notice.app
    if recent.count > 300 { recent.removeAll() }
  }

  static func name(_ bundle: String, title: String, body: String) -> String {
    var names = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    if let known = names[bundle] { return known }
    if let seen = recent[match(title, body)] {
      names[bundle] = seen
      UserDefaults.standard.set(names, forKey: key)
      return seen
    }
    return bundle.split(separator: ".").last.map(String.init) ?? bundle
  }

  private static func match(_ title: String, _ body: String) -> String {
    "\(title)|\(body)".replacingOccurrences(of: "\n", with: " ")
  }
}
