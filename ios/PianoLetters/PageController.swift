import SwiftUI
import UIKit
import WebKit

/// Shows the bundled page and answers its requests (keep awake, paste, updates, opened files).
final class PageController: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    private let store = ContentStore()
    private var isReady = false
    private var pendingImports: [String] = []

    lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalFiles(store: store), forURLScheme: LocalFiles.scheme)
        config.userContentController.add(self, name: "native")
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = self
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.086, green: 0.094, blue: 0.110, alpha: 1)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.bounces = false
        view.allowsBackForwardNavigationGestures = false
        #if DEBUG
        view.isInspectable = true
        #endif
        return view
    }()

    func loadPage() {
        isReady = false
        guard let url = URL(string: LocalFiles.scheme + "://app/index.html") else { return }
        webView.load(URLRequest(url: url))
    }

    // MARK: Files opened from Files or the share sheet

    func openFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), data.count < 60_000_000,
              let text = String(data: data, encoding: .utf8) else { return }
        if isReady { importSheets(text) } else { pendingImports.append(text) }
    }

    private func importSheets(_ text: String) {
        run("window.__plImport(" + Self.json(text) + ")")
    }

    // MARK: Messages from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? Int,
              let command = body["cmd"] as? String else { return }
        switch command {
        case "ready":
            isReady = true
            let waiting = pendingImports
            pendingImports = []
            waiting.forEach { importSheets($0) }
            reply(id, "ok")
        case "awake":
            UIApplication.shared.isIdleTimerDisabled = (body["arg"] as? Bool) ?? false
            reply(id, "ok")
        case "paste":
            reply(id, UIPasteboard.general.string ?? "")
        case "check":
            store.check { result in
                DispatchQueue.main.async { self.reply(id, result.rawValue) }
            }
        case "sheets":
            store.sheets { text in
                DispatchQueue.main.async { self.reply(id, text) }
            }
        case "install":
            store.install()
            loadPage()
        default:
            reply(id, "")
        }
    }

    private func reply(_ id: Int, _ value: String) {
        run("window.__plReply(" + String(id) + "," + Self.json(value) + ")")
    }

    private func run(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private static func json(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text), let out = String(data: data, encoding: .utf8) else { return "\"\"" }
        return out
    }

    // iPadOS may stop a page that was in the background for long.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadPage()
    }
}

struct PageView: UIViewRepresentable {
    let page: PageController

    func makeUIView(context: Context) -> WKWebView {
        page.loadPage()
        return page.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Serves the app's own files to the page at pianoletters://app/...
final class LocalFiles: NSObject, WKURLSchemeHandler {
    static let scheme = "pianoletters"
    private let store: ContentStore

    init(store: ContentStore) {
        self.store = store
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        var path = url.path
        if path.hasPrefix("/") { path.removeFirst() }
        if path.isEmpty { path = "index.html" }
        let data = store.data(for: path)
        let types = ["html": "text/html; charset=utf-8", "json": "application/json", "png": "image/png", "webmanifest": "application/manifest+json", "js": "text/javascript"]
        let type = types[(path as NSString).pathExtension] ?? "text/plain"
        let headers = ["Content-Type": type, "Content-Length": String(data?.count ?? 0), "Cache-Control": "no-store"]
        guard let response = HTTPURLResponse(url: url, statusCode: data == nil ? 404 : 200, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data ?? Data())
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
