import AppKit

/// A published build, read from the GitHub release feed that the Homebrew cask also points at.
struct Release {
  let version: String
  let page: URL
  let zip: URL?
  var isNewer: Bool { version.compare(Updater.currentVersion, options: .numeric) == .orderedDescending }
}

/// Checks for a newer published build and, when asked, puts it in place of this one.
///
/// The whole update is three steps with nothing hidden: read the release feed, download the zip the
/// release carries, and swap the app bundle only if the download is signed by the same team as this
/// build. Nothing is installed without the user pressing the button; the setting only governs the check.
final class Updater {
  static let shared = Updater()
  /// The releases feed rather than the API: api.github.com allows 60 anonymous calls an hour per
  /// address, which an office sharing one address burns through, and the check then fails for
  /// everyone behind it. The feed is plain HTTP with no such limit.
  private static let feed = URL(string: "https://github.com/ojtiger/pounce/releases.atom")!
  private static let repo = "https://github.com/ojtiger/pounce"

  static var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
  }

  /// A newer version was found by a background check. The app announces it once per version.
  var onNewVersion: ((Release) -> Void)?
  private var checking = false

  private func fail(_ message: String) -> NSError {
    NSError(domain: "pounce.update", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }

  // MARK: check

  func check(_ done: @escaping (Result<Release, Error>) -> Void) {
    var request = URLRequest(url: Self.feed)
    request.timeoutInterval = 15
    request.cachePolicy = .reloadIgnoringLocalCacheData
    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      guard let self else { return }
      DispatchQueue.main.async {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let data, status == 200, let feed = String(data: data, encoding: .utf8),
              let version = Self.newestVersion(in: feed) else {
          let why = error?.localizedDescription ?? T("릴리스 정보를 읽을 수 없습니다")
          logE("update check failed: status=\(status) \(why)")
          done(.failure(self.fail(why)))
          return
        }
        // Every release is published the same way, so the page and the file follow from the tag.
        let page = URL(string: "\(Self.repo)/releases/tag/v\(version)")!
        let zip = URL(string: "\(Self.repo)/releases/download/v\(version)/Pounce-\(version).zip")
        logI("update check: published \(version), running \(Self.currentVersion)")
        done(.success(Release(version: version, page: page, zip: zip)))
      }
    }.resume()
  }

  /// The newest version in the feed. Entries come newest first, but the highest number wins anyway
  /// so a re-published older tag cannot drag everyone backwards.
  private static func newestVersion(in feed: String) -> String? {
    let pattern = #"/releases/tag/v(\d+\.\d+\.\d+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(feed.startIndex..., in: feed)
    let versions = regex.matches(in: feed, range: range).compactMap { match -> String? in
      guard let r = Range(match.range(at: 1), in: feed) else { return nil }
      return String(feed[r])
    }
    return versions.max { $0.compare($1, options: .numeric) == .orderedAscending }
  }

  /// The scheduled check: at most once a day, only while the setting is on, and it announces a
  /// version once. Pressing 업데이트 확인 in 정보 goes through `check` directly and ignores all of this.
  func checkInBackground() {
    guard Settings.shared.autoUpdate, !checking else { return }
    let defaults = UserDefaults.standard
    let last = defaults.double(forKey: "lastUpdateCheck")
    guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
    checking = true
    check { [weak self] result in
      self?.checking = false
      defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
      guard case .success(let release) = result, release.isNewer else { return }
      guard defaults.string(forKey: "announcedVersion") != release.version else { return }
      defaults.set(release.version, forKey: "announcedVersion")
      self?.onNewVersion?(release)
    }
  }

  // MARK: install

  /// Downloads the release zip, checks its signature, and puts it where this app is running from.
  /// `progress` reports what is happening in words fit for the settings window.
  func install(_ release: Release, progress: @escaping (String) -> Void,
               done: @escaping (Result<Void, Error>) -> Void) {
    guard let zip = release.zip else {
      done(.failure(fail(T("릴리스에 내려받을 파일이 없습니다"))))
      return
    }
    progress(T("내려받는 중…"))
    URLSession.shared.downloadTask(with: zip) { [weak self] file, _, error in
      guard let self else { return }
      guard let file else {
        DispatchQueue.main.async { done(.failure(self.fail(error?.localizedDescription ?? T("내려받기 실패")))) }
        return
      }
      // The temporary file is gone the moment this callback returns, so move it somewhere of our own.
      let work = FileManager.default.temporaryDirectory
        .appendingPathComponent("pounce-update-\(UUID().uuidString)")
      let archive = work.appendingPathComponent("Pounce.zip")
      do {
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: archive)
      } catch {
        DispatchQueue.main.async { done(.failure(error)) }
        return
      }
      DispatchQueue.main.async { progress(T("설치 중…")) }
      DispatchQueue.global(qos: .userInitiated).async {
        let result = self.swapIn(archive: archive, work: work)
        DispatchQueue.main.async {
          try? FileManager.default.removeItem(at: work)
          done(result)
        }
      }
    }.resume()
  }

  private func swapIn(archive: URL, work: URL) -> Result<Void, Error> {
    let unpacked = work.appendingPathComponent("unpacked")
    guard run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path]).status == 0 else {
      return .failure(fail(T("압축을 풀지 못했습니다")))
    }
    let contents = (try? FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)) ?? []
    guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
      return .failure(fail(T("내려받은 파일에 앱이 없습니다")))
    }
    // Only a build signed by the same team replaces this one; a broken or foreign signature stops here.
    guard run("/usr/bin/codesign", ["--verify", "--strict", newApp.path]).status == 0 else {
      return .failure(fail(T("서명을 확인하지 못했습니다")))
    }
    let mine = teamIdentifier(of: Bundle.main.bundleURL.path)
    let theirs = teamIdentifier(of: newApp.path)
    if let mine, !mine.isEmpty, mine != theirs {
      logE("update refused: team \(theirs ?? "none") != \(mine)")
      return .failure(fail(T("다른 개발자가 서명한 빌드입니다")))
    }

    let dest = Bundle.main.bundleURL
    let backup = work.appendingPathComponent("previous.app")
    do {
      // The running process keeps its own copy of the bundle by inode, so moving it aside is safe.
      try FileManager.default.moveItem(at: dest, to: backup)
    } catch {
      logE("update: cannot move \(dest.path): \(error.localizedDescription)")
      return .failure(fail(T("%@ 폴더에 쓸 수 없습니다", dest.deletingLastPathComponent().lastPathComponent)))
    }
    guard run("/usr/bin/ditto", [newApp.path, dest.path]).status == 0 else {
      try? FileManager.default.removeItem(at: dest)
      try? FileManager.default.moveItem(at: backup, to: dest)
      return .failure(fail(T("앱을 바꾸지 못했습니다")))
    }
    logI("updated in place at \(dest.path)")
    return .success(())
  }

  /// Starts the freshly installed app once this one is out of the way, then ends this process.
  func relaunch() {
    let path = Bundle.main.bundleURL.path
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", "sleep 1; /usr/bin/open \"\(path)\""]
    try? task.run()
    logI("relaunching after update")
    NSApp.terminate(nil)
  }

  // MARK: shell

  @discardableResult
  private func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do { try task.run() } catch { return (-1, error.localizedDescription) }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    return (task.terminationStatus, String(decoding: data, as: UTF8.self))
  }

  private func teamIdentifier(of path: String) -> String? {
    let out = run("/usr/bin/codesign", ["-dv", path]).output
    return out.split(separator: "\n").first { $0.hasPrefix("TeamIdentifier=") }
      .map { String($0.dropFirst("TeamIdentifier=".count)) }
      .flatMap { $0 == "not set" ? nil : $0 }
  }
}
