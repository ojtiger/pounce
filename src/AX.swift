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
    queue.async {
      if !FileManager.default.fileExists(atPath: self.url.path) {
        FileManager.default.createFile(atPath: self.url.path, contents: nil)
      }
      guard let handle = try? FileHandle(forWritingTo: self.url) else { return }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      handle.write(Data(line.utf8))
    }
  }
}

func logI(_ m: String) { Log.shared.write("INFO", m) }
func logE(_ m: String) { Log.shared.write("ERROR", m) }
func logD(_ m: String) { if Log.shared.debugEnabled { Log.shared.write("DEBUG", m) } }

// MARK: - AX helpers

extension AXUIElement {
  func attr<T>(_ name: String, as _: T.Type) -> T? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(self, name as CFString, &ref) == .success else { return nil }
    return ref as? T
  }

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
  var isClose: Bool { ["닫기", "Close", "지우기", "Clear"].contains(label) }
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
