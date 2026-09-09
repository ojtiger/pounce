import AppKit
import ApplicationServices

// MARK: - Log

final class Log {
  static let shared = Log()
  let url = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/pounce.log")
  private let queue = DispatchQueue(label: "pounce.log")
  private let formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  var debugEnabled: Bool { UserDefaults.standard.bool(forKey: "debugLoggingEnabled") }

  init() {
    // Keep the log from growing without bound.
    if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, size > 2_000_000 {
      try? FileManager.default.removeItem(at: url)
    }
  }

  func write(_ level: String, _ message: String) {
    let line = "[\(level)] \(formatter.string(from: Date())) \(message)\n"
    queue.async { self.append(line) }
  }

  /// The same, on the caller's thread. For last words before the process goes: the queue would
  /// never get its turn.
  func writeNow(_ level: String, _ message: String) {
    let line = "[\(level)] \(formatter.string(from: Date())) \(message)\n"
    queue.sync { self.append(line) }
  }

  /// Empties the log in place. Truncating rather than deleting keeps the file — and the descriptor
  /// the crash handler holds open on it — pointing at the same place.
  func clear() {
    queue.sync {
      guard let handle = try? FileHandle(forWritingTo: self.url) else {
        FileManager.default.createFile(atPath: self.url.path, contents: nil)
        return
      }
      defer { try? handle.close() }
      try? handle.truncate(atOffset: 0)
    }
  }

  /// Always on `queue`.
  private func append(_ line: String) {
    if !FileManager.default.fileExists(atPath: url.path) {
      FileManager.default.createFile(atPath: url.path, contents: nil)
    }
    guard let handle = try? FileHandle(forWritingTo: url) else { return }
    defer { try? handle.close() }
    _ = try? handle.seekToEnd()
    handle.write(Data(line.utf8))
  }
}

func logI(_ m: String) { Log.shared.write("INFO", m) }
func logE(_ m: String) { Log.shared.write("ERROR", m) }
func logD(_ m: String) { if Log.shared.debugEnabled { Log.shared.write("DEBUG", m) } }

// MARK: - AX helpers

/// What an accessibility read actually said. "The value is not there" and "the read did not
/// happen" are different facts, and every decision about whether a banner is still on screen turns
/// on telling them apart: a tree that cannot be read must never be mistaken for an empty one.
enum AXRead<T> {
  case ok(T)
  /// The element answered and carries nothing under this attribute.
  case absent
  /// The element is gone. `kAXErrorInvalidUIElement` is the only answer that proves this.
  case dead
  /// The read did not happen — busy, timed out, refused. Nothing may be concluded from it.
  case unknown(AXError)

  var value: T? {
    if case .ok(let v) = self { return v }
    return nil
  }

  var isDead: Bool {
    if case .dead = self { return true }
    return false
  }
}

extension AXUIElement {
  /// The whole answer, error and all. Everything else here is built on this.
  func read<T>(_ name: String, as _: T.Type) -> AXRead<T> {
    var ref: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(self, name as CFString, &ref)
    switch err {
    case .success:
      guard let v = ref as? T else { return .absent }
      return .ok(v)
    case .noValue, .attributeUnsupported:
      return .absent
    case .invalidUIElement:
      return .dead
    default:
      return .unknown(err)
    }
  }

  /// Whether the element still exists. Only `invalidUIElement` proves it does not; every other
  /// unhappy answer means we do not know, which is not the same thing and must not be treated as one.
  var liveness: AXRead<Bool> {
    switch read(kAXRoleAttribute, as: String.self) {
    case .ok, .absent: return .ok(true)
    case .dead: return .dead
    case .unknown(let e): return .unknown(e)
    }
  }

  /// Children, keeping the difference between "has none" and "could not ask".
  func childList() -> AXRead<[AXUIElement]> {
    switch read(kAXChildrenAttribute, as: [AXUIElement].self) {
    case .ok(let c): return .ok(c)
    case .absent: return .ok([])
    case .dead: return .dead
    case .unknown(let e): return .unknown(e)
    }
  }

  /// The position, with the same distinction kept: a read that failed is not a window that moved.
  func readPoint(_ name: String = kAXPositionAttribute) -> AXRead<CGPoint> {
    switch read(name, as: AXValue.self) {
    case .ok(let v):
      var p = CGPoint.zero
      return AXValueGetValue(v, .cgPoint, &p) ? .ok(p) : .unknown(.failure)
    case .absent: return .absent
    case .dead: return .dead
    case .unknown(let e): return .unknown(e)
    }
  }

  func attr<T>(_ name: String, as _: T.Type) -> T? { read(name, as: T.self).value }

  var role: String? { attr(kAXRoleAttribute, as: String.self) }
  var subrole: String? { attr(kAXSubroleAttribute, as: String.self) }
  var identifier: String? { attr(kAXIdentifierAttribute, as: String.self) }
  var title: String? { attr(kAXTitleAttribute, as: String.self) }
  var value: String? { attr(kAXValueAttribute, as: String.self) }
  var desc: String? { attr(kAXDescriptionAttribute, as: String.self) }
  var attributedDescription: String? { attr("AXAttributedDescription", as: String.self) }

  func children() -> [AXUIElement] {
    attr(kAXChildrenAttribute, as: [AXUIElement].self) ?? []
  }

  func point(_ name: String = kAXPositionAttribute) -> CGPoint? {
    guard let v = attr(name, as: AXValue.self) else { return nil }
    var p = CGPoint.zero
    return AXValueGetValue(v, .cgPoint, &p) ? p : nil
  }

  func size() -> CGSize? {
    guard let v = attr(kAXSizeAttribute, as: AXValue.self) else { return nil }
    var s = CGSize.zero
    return AXValueGetValue(v, .cgSize, &s) ? s : nil
  }

  func frame() -> CGRect? {
    guard let p = point(), let s = size() else { return nil }
    return CGRect(origin: p, size: s)
  }

  func isSettable(_ name: String) -> Bool {
    var settable: DarwinBoolean = false
    return AXUIElementIsAttributeSettable(self, name as CFString, &settable) == .success && settable.boolValue
  }

  @discardableResult
  func setPosition(_ p: CGPoint) -> AXError {
    var pt = p
    guard let v = AXValueCreate(.cgPoint, &pt) else { return .failure }
    return AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, v)
  }

  func actions() -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(self, &names) == .success else { return [] }
    return names as? [String] ?? []
  }

  /// Notification Center exposes its buttons as custom actions whose names look like
  /// "Name:보기\nTarget:0x0\nSelector:(null)". Keep the raw name for performing, a label for showing.
  func customActions() -> [AXAction] {
    actions().compactMap { raw in
      guard raw.hasPrefix("Name:") else { return nil }
      let label = raw.dropFirst(5).split(separator: "\n", maxSplits: 1).first.map { cleanAX(String($0)) } ?? ""
      return label.isEmpty ? nil : AXAction(label: label, name: raw)
    }
  }

  @discardableResult
  func perform(_ name: String) -> AXError {
    AXUIElementPerformAction(self, name as CFString)
  }

  @discardableResult
  func press() -> AXError {
    AXUIElementPerformAction(self, kAXPressAction as CFString)
  }

  /// Cleaned values of all AXStaticText descendants in tree order.
  func staticTexts(depth: Int = 0) -> [String] {
    guard depth < 8 else { return [] }
    var out: [String] = []
    if role == kAXStaticTextRole as String, let v = value {
      let c = cleanAX(v)
      if !c.isEmpty { out.append(c) }
    }
    for child in children() { out.append(contentsOf: child.staticTexts(depth: depth + 1)) }
    return out
  }

  /// The first image anywhere under this element, with the attribute names it carries: what the
  /// system hands over for an attachment, if anything, decides whether a card can draw it.
  func firstImage(depth: Int = 0) -> (AXUIElement, [String])? {
    guard depth < 8 else { return nil }
    if role == kAXImageRole as String {
      var names: CFArray?
      AXUIElementCopyAttributeNames(self, &names)
      return (self, (names as? [String]) ?? [])
    }
    for child in children() {
      if let found = child.firstImage(depth: depth + 1) { return found }
    }
    return nil
  }

  /// One-line summary for logs.
  var summary: String {
    var parts = [role ?? "?"]
    if let s = subrole { parts.append("[\(s)]") }
    if let i = identifier, !i.isEmpty { parts.append("id=\(i)") }
    if let t = title, !t.isEmpty { parts.append("title=\"\(t)\"") }
    if let v = value, !v.isEmpty { parts.append("value=\"\(v.replacingOccurrences(of: "\n", with: "⏎"))\"") }
    if let d = attributedDescription, !d.isEmpty { parts.append("desc=\"\(d.replacingOccurrences(of: "\n", with: "⏎"))\"") }
    if let f = frame() { parts.append("@(\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))×\(Int(f.height)))") }
    let a = actions()
    if !a.isEmpty { parts.append("actions=\(a.joined(separator: ","))") }
    return parts.joined(separator: " ")
  }

  func dump(depth: Int = 0, maxDepth: Int = 7, into lines: inout [String]) {
    guard depth <= maxDepth else { return }
    lines.append(String(repeating: "  ", count: depth) + summary)
    for child in children() { child.dump(depth: depth + 1, maxDepth: maxDepth, into: &lines) }
  }
}

struct AXAction {
  let label: String
  let name: String

  /// Compared with case and stray spaces taken out: apps write their buttons however they please.
  private var key: String { label.trimmingCharacters(in: .whitespaces).lowercased() }

  /// The banner's own dismissal. The X in the card corner is already that button.
  var isClose: Bool { Self.close.contains(key) }

  /// Notification Center puts this on every banner: it unfolds the banner to reveal the text.
  /// The card shows that text from the start, so the button has nothing left to do.
  var isExpand: Bool { Self.expand.contains(key) }

  /// Brings the app forward and nothing more. A click on the card already does exactly that.
  var isOpenApp: Bool { Self.openApp.contains(key) }

  /// Buttons are handed over as "Name:답장\nTarget:0x0\nSelector:(null)" whatever they do, so what
  /// a button is can only be read from what it is called. The names come in the system's language
  /// for the first two lists and in each app's own for the third, so both are covered for every
  /// language Pounce speaks. A name no list has seen is caught the slow way, by watching a press.
  private static let close: Set<String> = [
    "닫기", "지우기",
    "close", "dismiss", "clear",
    "閉じる", "消去", "关闭", "清除", "關閉",
    "cerrar", "descartar", "borrar",
    "fermer", "ignorer", "effacer",
    "schließen", "ablehnen", "löschen",
    "chiudi", "ignora", "cancella",
    "fechar", "dispensar", "limpar",
    "закрыть", "отклонить", "очистить",
    "sluiten", "negeren", "wissen",
    "zamknij", "odrzuć", "wyczyść",
    "kapat", "yoksay", "temizle",
    "đóng", "bỏ qua", "xóa",
    "tutup", "abaikan", "hapus",
  ]

  private static let expand: Set<String> = [
    "세부사항 보기", "자세히 보기",
    "show details", "show more",
    "詳細を表示", "显示详细信息", "顯示詳細資訊",
    "mostrar detalles", "afficher les détails", "details einblenden", "details anzeigen",
    "mostra dettagli", "mostrar detalhes",
    "показать подробности", "details tonen", "pokaż szczegóły",
    "ayrıntıları göster", "xem chi tiết", "tampilkan detail",
  ]

  private static let openApp: Set<String> = [
    "보기", "열기", "이동",
    "show", "open", "view", "reveal", "launch", "go", "show me",
    "表示", "開く", "查看", "打开", "檢視", "開啟",
    "ver", "abrir", "mostrar",
    "voir", "ouvrir", "afficher",
    "anzeigen", "öffnen", "ansehen",
    "mostra", "apri", "vedi",
    "показать", "открыть", "перейти",
    "bekijken", "openen", "tonen",
    "pokaż", "otwórz", "zobacz",
    "göster", "aç", "git",
    "xem", "mở", "chuyển đến",
    "lihat", "buka",
  ]
}

/// Strips default-ignorable scalars (some apps embed U+200E) and trims spaces.
func cleanAX(_ s: String) -> String {
  s.unicodeScalars
    .filter { !$0.properties.isDefaultIgnorableCodePoint }
    .reduce(into: "") { $0.append(Character($1)) }
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

extension AXError {
  var name: String {
    switch self {
    case .success: return "success"
    case .failure: return "failure"
    case .illegalArgument: return "illegalArgument"
    case .invalidUIElement: return "invalidUIElement"
    case .invalidUIElementObserver: return "invalidUIElementObserver"
    case .cannotComplete: return "cannotComplete"
    case .attributeUnsupported: return "attributeUnsupported"
    case .actionUnsupported: return "actionUnsupported"
    case .notificationUnsupported: return "notificationUnsupported"
    case .notImplemented: return "notImplemented"
    case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
    case .notificationNotRegistered: return "notificationNotRegistered"
    case .apiDisabled: return "apiDisabled"
    case .noValue: return "noValue"
    case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
    case .notEnoughPrecision: return "notEnoughPrecision"
    @unknown default: return "unknown(\(rawValue))"
    }
  }
}
