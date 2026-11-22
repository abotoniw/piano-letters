import Foundation
import CryptoKit

/// The page and scores: the copy inside the app, or a newer one downloaded from the GitHub Pages site.
final class ContentStore {
    static let site = URL(string: "https://abotoniw.github.io/piano-letters/")!

    struct Manifest: Codable {
        struct File: Codable {
            let path: String
            let sha256: String
        }
        let version: String
        let built: Int
        let files: [File]
    }

    enum CheckResult: String {
        case new      // a newer copy is downloaded and waiting
        case same     // nothing newer
        case old      // the site is still being updated
        case offline  // no connection
    }

    private let files = FileManager.default
    private let current: URL   // downloaded copy in use, if any
    private let next: URL      // downloaded copy waiting to be installed
    private var root: URL      // where files are read from
    private var manifest: Manifest?

    init() {
        let support = files.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        current = support.appendingPathComponent("web", isDirectory: true)
        next = support.appendingPathComponent("web-next", isDirectory: true)
        let bundle = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        root = bundle
        manifest = ContentStore.readManifest(bundle)
        choose()
    }

    /// Uses the downloaded copy only when it is newer than the one inside the app.
    private func choose() {
        let bundle = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let inside = ContentStore.readManifest(bundle)
        let down = ContentStore.readManifest(current)
        if let down = down, down.built > (inside?.built ?? 0), isComplete(down, at: current) {
            root = current
            manifest = down
        } else {
            try? files.removeItem(at: current)
            root = bundle
            manifest = inside
        }
    }

    private static func readManifest(_ folder: URL) -> Manifest? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("version.json")) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    private func isComplete(_ m: Manifest, at folder: URL) -> Bool {
        return m.files.allSatisfy { files.fileExists(atPath: folder.appendingPathComponent($0.path).path) }
    }

    private static func isSafe(_ path: String) -> Bool {
        return !path.isEmpty && !path.hasPrefix("/") && !path.components(separatedBy: "/").contains("..")
    }

    func data(for path: String) -> Data? {
        guard ContentStore.isSafe(path) else { return nil }
        return try? Data(contentsOf: root.appendingPathComponent(path))
    }

    // MARK: Updates

    func check(_ done: @escaping (CheckResult) -> Void) {
        Task.detached { [self] in
            done(await download())
        }
    }

    /// The sheets placed in the repository as my-sheets.json, or an empty text when there are none.
    func sheets(_ done: @escaping (String) -> Void) {
        Task.detached { [self] in
            let data = await fetch("my-sheets.json")
            done(data.flatMap { String(data: $0, encoding: .utf8) } ?? "")
        }
    }

    private func fetch(_ path: String) async -> Data? {
        guard let base = URL(string: path, relativeTo: ContentStore.site),
              var parts = URLComponents(url: base, resolvingAgainstBaseURL: true) else { return nil }
        parts.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        guard let url = parts.url else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return result.0
    }

    private static func hash(_ data: Data) -> String {
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func download() async -> CheckResult {
        guard let raw = await fetch("version.json") else { return .offline }
        guard let remote = try? JSONDecoder().decode(Manifest.self, from: raw) else { return .old }
        if remote.built <= (manifest?.built ?? 0) { return .same }
        if let ready = ContentStore.readManifest(next), ready.version == remote.version, isComplete(ready, at: next) { return .new }
        do {
            try? files.removeItem(at: next)
            try files.createDirectory(at: next, withIntermediateDirectories: true)
            for file in remote.files {
                guard ContentStore.isSafe(file.path) else { return .old }
                let target = next.appendingPathComponent(file.path)
                try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let have = data(for: file.path), ContentStore.hash(have) == file.sha256 {
                    try have.write(to: target)
                    continue
                }
                guard let got = await fetch(file.path) else { try? files.removeItem(at: next); return .offline }
                guard ContentStore.hash(got) == file.sha256 else { try? files.removeItem(at: next); return .old }
                try got.write(to: target)
            }
            try raw.write(to: next.appendingPathComponent("version.json")) // last, so a half download is never used
            return .new
        } catch {
            try? files.removeItem(at: next)
            return .offline
        }
    }

    func install() {
        guard let ready = ContentStore.readManifest(next), isComplete(ready, at: next) else { return }
        try? files.removeItem(at: current)
        try? files.moveItem(at: next, to: current)
        choose()
    }
}
