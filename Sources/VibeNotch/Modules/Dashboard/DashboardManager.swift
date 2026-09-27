import SwiftUI
import Foundation
import WebKit

struct DynamicMetricItem: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let displayTitle: String
    let value: String
    let icon: String
    let color: Color
}

struct DynamicStatusItem: Identifiable, Equatable {
    var id: String
    let name: String
    let statusText: String
    let statusColor: Color
    let detail: String?
}

struct DashboardSiteProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var baseUrl: String
    var loginPath: String
    var statsApiPath: String
}

// Standard Dashboard Structures
struct DashboardUsersStats: Codable, Equatable {
    var totalUsers: Int = 0
    var newUsers7d: Int = 0
    var activeUsers7d: Int = 0
    var analyses7d: Int = 0
    var marksTotal: Int = 0
}

struct DashboardSourceItem: Codable, Identifiable, Equatable {
    var id: String { source }
    var source: String
    var last_ok: String?
    var last_fail: String?
    var fail_streak: Int = 0
    var calls: Int = 0
    var oks: Int = 0
    
    var statusText: String {
        if fail_streak >= 5 { return "Умер" }
        if fail_streak >= 2 || calls == 0 { return "Сбоит" }
        return "Работает"
    }
    
    var statusColor: Color {
        if fail_streak >= 5 { return .red }
        if fail_streak >= 2 || calls == 0 { return .orange }
        return .green
    }
}

struct DashboardStatsResponse: Codable {
    var users: DashboardUsersStats?
    var sources: [DashboardSourceItem]?
}

@MainActor
class DashboardManager: ObservableObject {
    static let shared = DashboardManager()
    
    // Multi-site profiles
    @Published var profiles: [DashboardSiteProfile] = []
    @Published var currentProfileId: String = ""
    
    // Website connection configuration
    @Published var baseUrl: String = {
        UserDefaults.standard.string(forKey: "DashboardBaseUrl") ?? "https://example.com"
    }() {
        didSet {
            UserDefaults.standard.set(baseUrl, forKey: "DashboardBaseUrl")
        }
    }
    
    @Published var loginPath: String = {
        UserDefaults.standard.string(forKey: "DashboardLoginPath") ?? "/login"
    }() {
        didSet {
            UserDefaults.standard.set(loginPath, forKey: "DashboardLoginPath")
        }
    }
    
    @Published var statsApiPath: String = {
        UserDefaults.standard.string(forKey: "DashboardStatsApiPath") ?? "/api/admin/stats"
    }() {
        didSet {
            UserDefaults.standard.set(statsApiPath, forKey: "DashboardStatsApiPath")
        }
    }
    
    @Published var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "DashboardIsLoggedIn") {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "DashboardIsLoggedIn")
        }
    }
    
    @Published var authCookieOrToken: String = "" {
        didSet {
            KeychainHelper.save(key: "DashboardAuthCookie", value: authCookieOrToken)
        }
    }
    
    // Dynamic parsed metrics & statuses (Works for ANY site!)
    @Published var metricsList: [DynamicMetricItem] = []
    @Published var statusChipsList: [DynamicStatusItem] = []
    
    // Standard metrics
    @Published var usersStats: DashboardUsersStats = DashboardUsersStats()
    @Published var sourcesList: [DashboardSourceItem] = []
    
    @Published var isOnline: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    
    private var refreshTimer: Timer?
    
    init() {
        // Load or migrate auth token securely from/to Keychain
        if let keychainToken = KeychainHelper.load(key: "DashboardAuthCookie"), !keychainToken.isEmpty {
            self.authCookieOrToken = keychainToken
            UserDefaults.standard.removeObject(forKey: "DashboardAuthCookie")
        } else if let legacyToken = UserDefaults.standard.string(forKey: "DashboardAuthCookie"), !legacyToken.isEmpty {
            KeychainHelper.save(key: "DashboardAuthCookie", value: legacyToken)
            UserDefaults.standard.removeObject(forKey: "DashboardAuthCookie")
            self.authCookieOrToken = legacyToken
        }
        
        loadProfiles()
        startTimer()
        checkInitialSession()
    }
    
    func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: "DashboardProfiles"),
           let decoded = try? JSONDecoder().decode([DashboardSiteProfile].self, from: data),
           !decoded.isEmpty {
            self.profiles = decoded
        } else {
            let defaultProfile = DashboardSiteProfile(
                id: "default",
                name: "Мой проект",
                baseUrl: baseUrl.isEmpty ? "https://example.com" : baseUrl,
                loginPath: loginPath.isEmpty ? "/login" : loginPath,
                statsApiPath: statsApiPath.isEmpty ? "/api/admin/stats" : statsApiPath
            )
            self.profiles = [defaultProfile]
            saveProfiles()
        }
        
        let savedActiveId = UserDefaults.standard.string(forKey: "DashboardCurrentProfileId") ?? ""
        if let active = profiles.first(where: { $0.id == savedActiveId }) {
            currentProfileId = active.id
            applyProfile(active)
        } else if let first = profiles.first {
            currentProfileId = first.id
            applyProfile(first)
        }
    }
    
    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "DashboardProfiles")
        }
    }
    
    func selectProfile(id: String) {
        guard let p = profiles.first(where: { $0.id == id }) else { return }
        currentProfileId = p.id
        UserDefaults.standard.set(p.id, forKey: "DashboardCurrentProfileId")
        applyProfile(p)
        checkInitialSession()
    }
    
    func applyProfile(_ p: DashboardSiteProfile) {
        self.baseUrl = p.baseUrl
        self.loginPath = p.loginPath
        self.statsApiPath = p.statsApiPath
    }
    
    func addNewProfile(name: String, baseUrl: String, loginPath: String = "/login", statsApiPath: String = "/api/admin/stats") {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUrl = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let newP = DashboardSiteProfile(
            id: UUID().uuidString,
            name: cleanName.isEmpty ? "Сайт \(profiles.count + 1)" : cleanName,
            baseUrl: cleanUrl.isEmpty ? "https://mysite.com" : cleanUrl,
            loginPath: loginPath,
            statsApiPath: statsApiPath
        )
        profiles.append(newP)
        saveProfiles()
        selectProfile(id: newP.id)
    }
    
    func removeProfile(id: String) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        saveProfiles()
        if let first = profiles.first {
            selectProfile(id: first.id)
        }
    }
    
    func startTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchStats()
            }
        }
    }
    
    func getNormalizedBaseUrl() -> String {
        var clean = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            clean = "https://example.com"
        }
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            if clean.contains("localhost") || clean.contains("127.0.0.1") {
                clean = "http://" + clean
            } else {
                clean = "https://" + clean
            }
        }
        if clean.hasSuffix("/") {
            clean.removeLast()
        }
        return clean
    }
    
    func checkInitialSession() {
        let domain = URL(string: getNormalizedBaseUrl())?.host ?? "example.com"
        WebAuthManager.shared.checkHasSession(for: domain) { [weak self] hasSession in
            Task { @MainActor [weak self] in
                if hasSession {
                    self?.isLoggedIn = true
                    await self?.fetchStats()
                }
            }
        }
    }
    
    func startLoginFlow() {
        let cleanBase = getNormalizedBaseUrl()
        var cleanPath = loginPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        guard let url = URL(string: cleanBase + cleanPath) else {
            errorMessage = "Некорректный адрес входа: \(cleanBase + cleanPath)"
            return
        }
        
        WebAuthManager.shared.presentLoginWindow(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                self?.isLoggedIn = true
                self?.errorMessage = nil
                await self?.fetchStats()
            }
        }
    }
    
    func logout() {
        let domain = URL(string: getNormalizedBaseUrl())?.host ?? "example.com"
        WebAuthManager.shared.logout(domain: domain)
        self.isLoggedIn = false
        self.usersStats = DashboardUsersStats()
        self.sourcesList = []
        self.metricsList = []
        self.statusChipsList = []
        self.isOnline = false
        self.lastUpdated = nil
        self.errorMessage = nil
    }
    
    func fetchStats() async {
        isLoading = true
        defer { isLoading = false }
        
        let cleanBase = getNormalizedBaseUrl()
        var cleanPath = statsApiPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        guard let url = URL(string: cleanBase + cleanPath) else {
            errorMessage = "Некорректный адрес API"
            isOnline = false
            return
        }
        
        // Retrieve cookies from WKWebsiteDataStore for this domain
        let cookies = await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { allCookies in
                let matching = allCookies.filter { c in
                    if let host = url.host?.lowercased() {
                        let clean = c.domain.hasPrefix(".") ? String(c.domain.dropFirst()) : c.domain
                        return host.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains(host)
                    }
                    return false
                }
                continuation.resume(returning: matching)
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        
        // Format cookie header from WKWebsiteDataStore cookies + manual fallback
        var cookieParts = cookies.map { "\($0.name)=\($0.value)" }
        let cleanManual = authCookieOrToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanManual.isEmpty {
            cookieParts.append(cleanManual)
        }
        if !cookieParts.isEmpty {
            let cookieHeader = cookieParts.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    // 1. Try standard dashboard stats decode
                    if let decoded = try? JSONDecoder().decode(DashboardStatsResponse.self, from: data) {
                        if let u = decoded.users {
                            self.usersStats = u
                        }
                        if let s = decoded.sources {
                            self.sourcesList = s
                        }
                    }
                    
                    // 2. Run Universal Dynamic JSON Parser (Works for ANY site!)
                    let (parsedMetrics, parsedStatuses) = parseJsonMetrics(from: data)
                    if !parsedMetrics.isEmpty {
                        self.metricsList = parsedMetrics
                    }
                    if !parsedStatuses.isEmpty {
                        self.statusChipsList = parsedStatuses
                    }
                    
                    self.isOnline = true
                    self.isLoggedIn = true
                    self.lastUpdated = Date()
                    self.errorMessage = nil
                    return
                } else if http.statusCode == 401 || http.statusCode == 404 || http.statusCode == 403 {
                    self.isLoggedIn = false
                    self.isOnline = false
                    self.errorMessage = "Требуется авторизация на сайте (HTTP \(http.statusCode))"
                    return
                } else {
                    self.errorMessage = "HTTP ошибка сервера: \(http.statusCode)"
                    self.isOnline = false
                    return
                }
            }
        } catch {
            self.errorMessage = "Сервер недоступен: \(error.localizedDescription)"
            self.isOnline = false
        }
    }
    
    // MARK: - Universal Dynamic JSON Auto-Parser
    func parseJsonMetrics(from data: Data) -> (metrics: [DynamicMetricItem], statuses: [DynamicStatusItem]) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = jsonObject as? [String: Any] else {
            return ([], [])
        }
        
        var metrics: [DynamicMetricItem] = []
        var statuses: [DynamicStatusItem] = []
        
        // Recursive helper to traverse dictionary
        func traverse(_ d: [String: Any], prefix: String = "", depth: Int = 0) {
            guard depth < 3 else { return }
            
            for (key, val) in d {
                let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
                
                if let num = val as? NSNumber {
                    let (title, icon, color) = analyzeKey(key)
                    let formattedVal = formatDynamicValue(num)
                    metrics.append(DynamicMetricItem(
                        key: fullKey,
                        displayTitle: title,
                        value: formattedVal,
                        icon: icon,
                        color: color
                    ))
                } else if let str = val as? String {
                    // Only concise strings can be KPI cards (e.g. "$1,200", "99.9%", "Online")
                    if str.count <= 24 && !str.hasPrefix("http") && !str.contains("\n") && !str.contains("{") {
                        let (title, icon, color) = analyzeKey(key)
                        metrics.append(DynamicMetricItem(
                            key: fullKey,
                            displayTitle: title,
                            value: str,
                            icon: icon,
                            color: color
                        ))
                    }
                } else if let subDict = val as? [String: Any] {
                    // Sub-object like "users": { "totalUsers": ... } or "metrics": { ... }
                    traverse(subDict, prefix: "", depth: depth + 1)
                } else if let array = val as? [[String: Any]] {
                    // Array of items (e.g. "sources", "services", "servers", "workers")
                    for (index, itemDict) in array.enumerated() {
                        if let statusItem = parseStatusDict(itemDict, defaultId: "\(key)_\(index)") {
                            statuses.append(statusItem)
                        }
                    }
                }
            }
        }
        
        traverse(dict)
        
        // Limit metrics to 8 to fit nicely in the notch
        let finalMetrics = Array(metrics.prefix(8))
        return (finalMetrics, statuses)
    }
    
    private func analyzeKey(_ key: String) -> (title: String, icon: String, color: Color) {
        let title = friendlyTitle(for: key)
        let (icon, color) = iconAndColor(for: key)
        return (title, icon, color)
    }
    
    private func friendlyTitle(for key: String) -> String {
        let lower = key.lowercased()
        switch lower {
        case "totalusers", "total_users", "users_total", "userstotal":
            return "ПОЛЬЗОВАТЕЛИ"
        case "newusers7d", "new_users_7d", "newusers", "new_users":
            return "НОВЫЕ (7Д)"
        case "activeusers7d", "active_users_7d", "activeusers", "active_users":
            return "АКТИВНЫЕ (7Д)"
        case "analyses7d", "analyses_7d", "analyses", "requests_total":
            return "АНАЛИЗЫ (7Д)"
        case "markstotal", "marks_total", "ratings_total", "scores_total", "reviews":
            return "ОЦЕНКИ"
        case "revenue", "total_revenue", "mrr", "income":
            return "ВЫРУЧКА"
        case "orders", "orders_count", "total_orders":
            return "ЗАКАЗЫ"
        case "sales", "total_sales":
            return "ПРОДАЖИ"
        case "conversion", "conversion_rate":
            return "КОНВЕРСИЯ"
        case "latency", "ping":
            return "ПИНГ"
        case "cpu", "cpu_usage", "cpuload":
            return "CPU"
        case "memory", "ram", "ram_usage":
            return "ПАМЯТЬ"
        case "uptime":
            return "АПТАЙМ"
        default:
            return formatCamelOrSnakeCase(key)
        }
    }
    
    private func formatCamelOrSnakeCase(_ key: String) -> String {
        var result = ""
        for char in key {
            if char.isUppercase {
                result.append(" ")
                result.append(char)
            } else if char == "_" || char == "-" {
                result.append(" ")
            } else {
                result.append(char)
            }
        }
        let cleaned = result.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "7d", with: " (7D)", options: .caseInsensitive)
            .replacingOccurrences(of: "30d", with: " (30D)", options: .caseInsensitive)
            .replacingOccurrences(of: "24h", with: " (24H)", options: .caseInsensitive)
        return cleaned.uppercased()
    }
    
    private func iconAndColor(for key: String) -> (icon: String, color: Color) {
        let lower = key.lowercased()
        if lower.contains("user") || lower.contains("member") || lower.contains("client") || lower.contains("cust") {
            if lower.contains("new") || lower.contains("reg") || lower.contains("plus") {
                return ("person.badge.plus.fill", .green)
            }
            return ("person.2.fill", .blue)
        }
        if lower.contains("active") || lower.contains("live") || lower.contains("speed") || lower.contains("load") || lower.contains("cpu") {
            return ("bolt.fill", .orange)
        }
        if lower.contains("analys") || lower.contains("magic") || lower.contains("ai") || lower.contains("pred") {
            return ("sparkles", .purple)
        }
        if lower.contains("mark") || lower.contains("score") || lower.contains("star") || lower.contains("rating") || lower.contains("review") {
            return ("star.fill", .yellow)
        }
        if lower.contains("money") || lower.contains("rev") || lower.contains("mrr") || lower.contains("sale") || lower.contains("pay") || lower.contains("price") || lower.contains("income") {
            return ("dollarsign.circle.fill", .green)
        }
        if lower.contains("order") || lower.contains("cart") || lower.contains("checkout") {
            return ("cart.fill", .cyan)
        }
        if lower.contains("fail") || lower.contains("err") || lower.contains("warn") || lower.contains("drop") {
            return ("exclamationmark.triangle.fill", .red)
        }
        if lower.contains("req") || lower.contains("hit") || lower.contains("call") || lower.contains("traffic") || lower.contains("ping") || lower.contains("lat") {
            return ("waveform.path.ecg", .indigo)
        }
        if lower.contains("server") || lower.contains("node") || lower.contains("host") || lower.contains("mem") || lower.contains("ram") || lower.contains("db") || lower.contains("disk") {
            return ("server.rack", .teal)
        }
        if lower.contains("time") || lower.contains("hour") || lower.contains("dur") || lower.contains("clock") {
            return ("clock.fill", .mint)
        }
        return ("chart.bar.fill", .cyan)
    }
    
    private func formatDynamicValue(_ num: NSNumber) -> String {
        if CFGetTypeID(num) == CFBooleanGetTypeID() {
            return num.boolValue ? "ДА" : "НЕТ"
        }
        let d = num.doubleValue
        if d.rounded() == d {
            let intVal = num.intValue
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = " "
            return formatter.string(from: NSNumber(value: intVal)) ?? "\(intVal)"
        } else {
            return String(format: "%.1f", d)
        }
    }
    
    private func parseStatusDict(_ dict: [String: Any], defaultId: String) -> DynamicStatusItem? {
        let nameCandidates = ["source", "name", "service", "server", "worker", "queue", "title", "id", "label", "host"]
        var foundName: String? = nil
        for cand in nameCandidates {
            if let val = dict[cand] as? String, !val.isEmpty {
                foundName = val
                break
            }
        }
        guard let name = foundName else { return nil }
        
        var statusText = "Работает"
        var statusColor = Color.green
        
        if let failStreak = dict["fail_streak"] as? Int {
            if failStreak >= 5 {
                statusText = "Умер"
                statusColor = .red
            } else if failStreak >= 2 || (dict["calls"] as? Int == 0) {
                statusText = "Сбоит"
                statusColor = .orange
            } else {
                statusText = "Работает"
                statusColor = .green
            }
        } else if let statusStr = (dict["status"] ?? dict["state"] ?? dict["health"]) as? String {
            let low = statusStr.lowercased()
            if low.contains("ok") || low.contains("online") || low.contains("up") || low.contains("health") || low.contains("pass") || low.contains("work") {
                statusText = statusStr.capitalized
                statusColor = .green
            } else if low.contains("deg") || low.contains("warn") || low.contains("slow") || low.contains("retry") {
                statusText = statusStr.capitalized
                statusColor = .orange
            } else {
                statusText = statusStr.capitalized
                statusColor = .red
            }
        } else if let boolOk = (dict["is_ok"] ?? dict["ok"] ?? dict["healthy"] ?? dict["active"]) as? Bool {
            statusText = boolOk ? "Работает" : "Сбой"
            statusColor = boolOk ? .green : .red
        }
        
        var detail: String? = nil
        if let calls = dict["calls"] as? Int {
            detail = "(\(calls) req)"
        } else if let latency = (dict["latency"] ?? dict["ping"] ?? dict["response_time"]) as? NSNumber {
            detail = "(\(latency) ms)"
        } else if let count = (dict["count"] ?? dict["total"]) as? NSNumber {
            detail = "(\(count))"
        } else if let uptime = dict["uptime"] as? String {
            detail = "(\(uptime))"
        }
        
        return DynamicStatusItem(
            id: defaultId,
            name: name,
            statusText: statusText,
            statusColor: statusColor,
            detail: detail
        )
    }
}
