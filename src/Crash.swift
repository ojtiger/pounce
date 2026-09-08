import AppKit
import Darwin

// MARK: - Crash

/// Why the last run ended, and what to leave behind if this one ends badly. Everything lands in the
/// one log the user already knows how to send.
///
/// Three things, in the order they are worth anything:
///  1. macOS writes a full report to ~/Library/Logs/DiagnosticReports whenever the app is taken
///     down. The next launch summarises the newest one that has not been read yet into pounce.log,
///     so the stack that killed it travels with the log rather than being left on the Mac.
///  2. A run that never said goodbye is written down, which is the only trace left when the app was
///     force quit or the Mac went down under it — no report is filed for those.
///  3. The signal handler writes its own backtrace first, for the case where the system report never
///     arrives: the bundle being replaced underneath, a crash during shutdown.
enum Crash {
  private static let runningKey = "crashRunInProgress"
  private static let lastReportKey = "crashLastReportSeen"

  /// Called before anything else can go wrong.
  static func install() {
    // The handler cannot allocate or take a lock, so the log is opened now and appended to raw.
    crashLogFD = open(Log.shared.url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
    for sig in [SIGILL, SIGTRAP, SIGABRT, SIGFPE, SIGBUS, SIGSEGV] { signal(sig, handleCrashSignal) }
    NSSetUncaughtExceptionHandler { e in
      // Still on a live thread here, so the whole exception fits in the log.
      Log.shared.writeNow("ERROR", "uncaught exception \(e.name.rawValue): \(e.reason ?? "")")
      Log.shared.writeNow("ERROR", "  " + e.callStackSymbols.joined(separator: "\n  "))
    }
    noteStart()
  }

  /// The app is going down on purpose. Anything else counts as a bad ending.
  static func noteCleanExit() { UserDefaults.standard.set(false, forKey: runningKey) }

  private static func noteStart() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: runningKey) {
      logE("previous run ended without a clean exit — crashed, force quit, or the Mac went down")
    }
    defaults.set(true, forKey: runningKey)
    summariseNewestReport()
  }

  /// The crash macOS itself recorded, in the few lines that say where it happened. Each report is
  /// summarised once; the file stays where it is for anyone who wants the whole thing.
  private static func summariseNewestReport() {
    let dir = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Logs/DiagnosticReports")
    guard let entries = try? FileManager.default.contentsOfDirectory(
      at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
    let reports = entries
      .filter { $0.lastPathComponent.hasPrefix("Pounce-") && $0.pathExtension == "ips" }
      .sorted { modified($0) > modified($1) }
    guard let newest = reports.first else { return }
    let name = newest.lastPathComponent
    guard name != UserDefaults.standard.string(forKey: lastReportKey) else { return }
    UserDefaults.standard.set(name, forKey: lastReportKey)

    // An .ips file is a one-line JSON header followed by the JSON body.
    guard let raw = try? String(contentsOf: newest, encoding: .utf8),
          let newline = raw.firstIndex(of: "\n"),
          let body = String(raw[raw.index(after: newline)...]).data(using: .utf8),
          let report = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
      logE("crash report \(name) could not be read")
      return
    }
    let exception = report["exception"] as? [String: Any] ?? [:]
    let type = exception["type"] as? String ?? "?"
    let signalName = exception["signal"] as? String ?? "?"
    logE("crash report \(name): \(type) / \(signalName)")

    let images = report["usedImages"] as? [[String: Any]] ?? []
    let threads = report["threads"] as? [[String: Any]] ?? []
    let faulting = report["faultingThread"] as? Int ?? 0
    guard faulting < threads.count, let frames = threads[faulting]["frames"] as? [[String: Any]] else { return }
    for frame in frames.prefix(14) {
      let index = frame["imageIndex"] as? Int ?? -1
      let image = index >= 0 && index < images.count ? (images[index]["name"] as? String ?? "?") : "?"
      let symbol = frame["symbol"] as? String ?? "+\(frame["imageOffset"] as? Int ?? 0)"
      logE("  \(image)  \(symbol)")
    }
  }

  private static func modified(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
  }
}

// MARK: - signal handler

/// Opened once at launch: a handler may not open files, allocate, or take a lock.
private var crashLogFD: Int32 = -1
private let crashBanner = strdup("\n[CRASH] fatal signal — backtrace follows\n")
private let crashFrames = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 64)

/// Writes the backtrace straight to the log's file descriptor, then lets the default handler run so
/// macOS still files its own report. Nothing here allocates.
private func handleCrashSignal(_ sig: Int32) {
  if crashLogFD >= 0, let banner = crashBanner {
    _ = write(crashLogFD, banner, strlen(banner))
    backtrace_symbols_fd(crashFrames, backtrace(crashFrames, 64), crashLogFD)
  }
  signal(sig, SIG_DFL)
  raise(sig)
}
