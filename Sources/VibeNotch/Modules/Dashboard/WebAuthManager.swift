import Cocoa
import WebKit

@MainActor
class WebAuthManager: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    static let shared = WebAuthManager()
    
    private var authWindow: NSWindow?
    private var webView: WKWebView?
    private var currentUrlField: NSTextField?
    private var targetHost: String = ""
    private var successCallback: (() -> Void)?
    
    // Desktop Safari User-Agent to allow Google OAuth without "disallowed_useragent" error 403
    private let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
    
    func presentLoginWindow(url: URL, onSuccess: @escaping () -> Void) {
        self.successCallback = onSuccess
        self.targetHost = url.host ?? ""
        
        // Ensure application becomes regular/interactive so window floats on top and accepts keyboard input
        NSApp.setActivationPolicy(.regular)
        
        // If window already exists, bring it forward and load
        if let window = authWindow, let wv = webView {
            window.level = .floating
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            wv.load(URLRequest(url: url))
            return
        }
        
        let config = WKWebViewConfiguration()
        // Default persistent data store so Google OAuth & site session cookies persist safely
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let windowWidth: CGFloat = 680
        let windowHeight: CGFloat = 740
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let hostName = url.host ?? "Сайт"
        window.title = "Вход на \(hostName) (Google / Пароль) — VibeNotch"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Root container
        let container = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        container.autoresizingMask = [.width, .height]
        
        // Top Toolbar
        let topBarHeight: CGFloat = 46
        let topBar = NSView(frame: NSRect(x: 0, y: windowHeight - topBarHeight, width: windowWidth, height: topBarHeight))
        topBar.autoresizingMask = [.width, .minYMargin]
        topBar.wantsLayer = true
        topBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let urlField = NSTextField(labelWithString: url.absoluteString)
        urlField.frame = NSRect(x: 14, y: 12, width: windowWidth - 230, height: 20)
        urlField.autoresizingMask = [.width]
        urlField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        urlField.textColor = .secondaryLabelColor
        urlField.lineBreakMode = .byTruncatingTail
        topBar.addSubview(urlField)
        self.currentUrlField = urlField
        
        let doneBtn = NSButton(title: "✓ Я вошел — Готово", target: self, action: #selector(manualDone))
        doneBtn.frame = NSRect(x: windowWidth - 200, y: 8, width: 186, height: 30)
        doneBtn.autoresizingMask = [.minXMargin]
        doneBtn.bezelStyle = .rounded
        doneBtn.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        topBar.addSubview(doneBtn)
        
        // WKWebView with Safari User-Agent
        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight - topBarHeight), configuration: config)
        wv.autoresizingMask = [.width, .height]
        wv.customUserAgent = safariUserAgent
        wv.navigationDelegate = self
        wv.uiDelegate = self
        self.webView = wv
        
        container.addSubview(wv)
        container.addSubview(topBar)
        
        window.contentView = container
        window.center()
        self.authWindow = window
        
        let request = URLRequest(url: url)
        wv.load(request)
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func manualDone() {
        closeWindow()
        successCallback?()
        successCallback = nil
    }
    
    func closeWindow() {
        authWindow?.close()
        authWindow = nil
        webView = nil
        currentUrlField = nil
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        authWindow = nil
        webView = nil
        currentUrlField = nil
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - WKUIDelegate (Handles window.open / popups for OAuth)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // If a script or button tries to open a popup window (e.g., Google OAuth popup), open it in the same webview!
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentUrl = webView.url?.absoluteString else { return }
        currentUrlField?.stringValue = currentUrl
        
        guard let host = webView.url?.host?.lowercased() else { return }
        
        // NEVER auto-close on Google or OAuth provider domains!
        if host.contains("google") || host.contains("gstatic") || host.contains("apple") || host.contains("telegram") {
            return
        }
        
        let path = webView.url?.path.lowercased() ?? ""
        let isBackOnTargetSite = !targetHost.isEmpty && host.contains(targetHost.lowercased())
        let isSuccessPage = path.contains("/admin") || path.contains("/account") || path.contains("/dashboard")
        
        // Auto-close only if we are back on the target site AND reached an authenticated page
        if isBackOnTargetSite && isSuccessPage {
            checkAndFinishIfSessionFound()
        }
    }
    
    private func checkAndFinishIfSessionFound() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            Task { @MainActor in
                guard let self = self else { return }
                let domain = self.targetHost.lowercased()
                let matchingCookies = cookies.filter { c in
                    let clean = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
                    return domain.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains(domain)
                }
                
                let hasSession = matchingCookies.contains { c in
                    let name = c.name.lowercased()
                    return name.contains("session") || name.contains("token") || name.contains("auth")
                }
                
                if hasSession {
                    self.closeWindow()
                    self.successCallback?()
                    self.successCallback = nil
                }
            }
        }
    }
    
    func checkHasSession(for domain: String, completion: @escaping @Sendable (Bool) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let cleanDomain = domain.lowercased()
            let hasValid = cookies.contains { c in
                let clean = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
                let matches = cleanDomain.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains(cleanDomain)
                let isSession = c.name.lowercased().contains("session") || c.name.lowercased().contains("token") || c.name.lowercased().contains("auth")
                return matches && isSession
            }
            completion(hasValid)
        }
    }
    
    func logout(domain: String) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let cleanDomain = domain.lowercased()
            for cookie in cookies {
                let clean = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                if cleanDomain.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains(cleanDomain) {
                    WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
                }
            }
        }
    }
}
