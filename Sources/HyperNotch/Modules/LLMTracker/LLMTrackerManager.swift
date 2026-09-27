import SwiftUI
import Foundation
import AppKit

extension Int {
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

struct LLMQuotaWindow: Identifiable, Equatable {
    let id = UUID()
    var title: String // e.g. "Weekly Limit Remaining", "Five Hour Limit Remaining"
    var usedPercent: Double? // 0.0 ... 100.0 or nil
    var remainingPercent: Double? // 0.0 ... 100.0 or nil
    var usageText: String // e.g. "74%", "2%", "12 000 / 12 000"
    var resetDate: Date?
    var resetDescription: String?
    
    var effectiveRemaining: Double {
        if let rem = remainingPercent { return rem }
        if let used = usedPercent { return max(0.0, 100.0 - used) }
        return 100.0
    }
    
    var statusColor: Color {
        let rem = effectiveRemaining
        if rem >= 30 {
            return .green
        } else if rem >= 15 {
            return .orange
        } else {
            return .red
        }
    }
}

struct LLMQuotaInfo: Identifiable, Equatable {
    let id = UUID()
    var providerName: String
    var planName: String // e.g. "Gemini Models", "Coding Plan", "Pro Plan"
    var windows: [LLMQuotaWindow] = []
    var resetDate: Date? // Earliest actionable reset date for alarm
    var resetTimeDescription: String
    var detailText: String
    var isError: Bool = false
    
    var effectiveLowestRemaining: Double? {
        if windows.isEmpty { return nil }
        return windows.map(\.effectiveRemaining).min()
    }
    
    var utilizationPercent: Double? {
        if let rem = effectiveLowestRemaining {
            return max(0.0, 100.0 - rem)
        }
        return nil
    }
    
    var statusColor: Color {
        if isError { return .red }
        guard let rem = effectiveLowestRemaining else { return .green }
        if rem >= 30 {
            return .green
        } else if rem >= 15 {
            return .orange
        } else {
            return .red
        }
    }
    
    var modelName: String {
        get { planName }
        set { planName = newValue }
    }
}

struct CustomLLMProvider: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var baseUrl: String
    var apiKey: String
    var isEnabled: Bool = true
}

@MainActor
class LLMTrackerManager: ObservableObject {
    static let shared = LLMTrackerManager()
    
    // MARK: - Presets Toggles
    @Published var enableCodex: Bool = UserDefaults.standard.bool(forKey: "EnableCodex") {
        didSet { UserDefaults.standard.set(enableCodex, forKey: "EnableCodex") }
    }
    @Published var enableClaude: Bool = UserDefaults.standard.bool(forKey: "EnableClaude") {
        didSet { UserDefaults.standard.set(enableClaude, forKey: "EnableClaude") }
    }
    @Published var enableZai: Bool = (UserDefaults.standard.object(forKey: "EnableZai") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(enableZai, forKey: "EnableZai") }
    }
    @Published var enableGemini: Bool = (UserDefaults.standard.object(forKey: "EnableGemini") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(enableGemini, forKey: "EnableGemini") }
    }
    @Published var enableGrok: Bool = UserDefaults.standard.bool(forKey: "EnableGrok") {
        didSet { UserDefaults.standard.set(enableGrok, forKey: "EnableGrok") }
    }
    @Published var enableOpenRouter: Bool = UserDefaults.standard.bool(forKey: "EnableOpenRouter") {
        didSet { UserDefaults.standard.set(enableOpenRouter, forKey: "EnableOpenRouter") }
    }
    @Published var enableDeepSeek: Bool = UserDefaults.standard.bool(forKey: "EnableDeepSeek") {
        didSet { UserDefaults.standard.set(enableDeepSeek, forKey: "EnableDeepSeek") }
    }
    @Published var enableOllama: Bool = UserDefaults.standard.bool(forKey: "EnableOllama") {
        didSet { UserDefaults.standard.set(enableOllama, forKey: "EnableOllama") }
    }
    
    // MARK: - Preset API Keys & Endpoints (Stored in Apple Keychain)
    @Published var codexApiKey: String = "" {
        didSet { KeychainHelper.save(key: "CodexApiKey", value: codexApiKey) }
    }
    @Published var claudeSessionToken: String = "" {
        didSet { KeychainHelper.save(key: "ClaudeSessionToken", value: claudeSessionToken) }
    }
    @Published var zaiApiKey: String = "" {
        didSet { KeychainHelper.save(key: "ZaiApiKey", value: zaiApiKey) }
    }
    @Published var geminiApiKey: String = "" {
        didSet { KeychainHelper.save(key: "GeminiApiKey", value: geminiApiKey) }
    }
    @Published var grokApiKey: String = "" {
        didSet { KeychainHelper.save(key: "GrokApiKey", value: grokApiKey) }
    }
    @Published var openRouterApiKey: String = "" {
        didSet { KeychainHelper.save(key: "OpenRouterApiKey", value: openRouterApiKey) }
    }
    @Published var deepSeekApiKey: String = "" {
        didSet { KeychainHelper.save(key: "DeepSeekApiKey", value: deepSeekApiKey) }
    }
    @Published var ollamaHost: String = UserDefaults.standard.string(forKey: "OllamaHost") ?? "http://127.0.0.1:11434" {
        didSet { UserDefaults.standard.set(ollamaHost, forKey: "OllamaHost") }
    }
    
    // MARK: - Universal Custom Providers (Keys stored in Apple Keychain)
    @Published var customProviders: [CustomLLMProvider] = [] {
        didSet {
            var sanitized = customProviders
            for i in 0..<sanitized.count {
                KeychainHelper.save(key: "custom_key_\(sanitized[i].id)", value: sanitized[i].apiKey)
                sanitized[i].apiKey = ""
            }
            if let data = try? JSONEncoder().encode(sanitized) {
                UserDefaults.standard.set(data, forKey: "CustomLLMProviders")
            }
        }
    }
    @Published var customQuotas: [UUID: LLMQuotaInfo] = [:]
    
    // Preset Live Quotas
    @Published var codexQuota: LLMQuotaInfo? = nil
    @Published var claudeQuota: LLMQuotaInfo? = nil
    @Published var zaiQuota: LLMQuotaInfo? = nil
    @Published var geminiQuota: LLMQuotaInfo? = nil
    @Published var grokQuota: LLMQuotaInfo? = nil
    @Published var openRouterQuota: LLMQuotaInfo? = nil
    @Published var deepSeekQuota: LLMQuotaInfo? = nil
    @Published var ollamaQuota: LLMQuotaInfo? = nil
    
    @Published var isRefreshing: Bool = false
    @Published var alarmSetItemId: UUID? = nil
    private var refreshTimer: Timer?
    
    init() {
        // Securely load or migrate keys from UserDefaults into Apple Keychain
        self.codexApiKey = LLMTrackerManager.loadAndMigrate(key: "CodexApiKey")
        self.claudeSessionToken = LLMTrackerManager.loadAndMigrate(key: "ClaudeSessionToken")
        self.zaiApiKey = LLMTrackerManager.loadAndMigrate(key: "ZaiApiKey")
        self.geminiApiKey = LLMTrackerManager.loadAndMigrate(key: "GeminiApiKey")
        self.grokApiKey = LLMTrackerManager.loadAndMigrate(key: "GrokApiKey")
        self.openRouterApiKey = LLMTrackerManager.loadAndMigrate(key: "OpenRouterApiKey")
        self.deepSeekApiKey = LLMTrackerManager.loadAndMigrate(key: "DeepSeekApiKey")
        
        if let data = UserDefaults.standard.data(forKey: "CustomLLMProviders"),
           var decoded = try? JSONDecoder().decode([CustomLLMProvider].self, from: data) {
            for i in 0..<decoded.count {
                if let key = KeychainHelper.load(key: "custom_key_\(decoded[i].id)"), !key.isEmpty {
                    decoded[i].apiKey = key
                } else if !decoded[i].apiKey.isEmpty {
                    KeychainHelper.save(key: "custom_key_\(decoded[i].id)", value: decoded[i].apiKey)
                }
            }
            self.customProviders = decoded
        }
        
        startAutoRefresh()
        Task {
            await refreshAll()
        }
    }
    
    private static func loadAndMigrate(key: String) -> String {
        // 1. If already saved in Keychain, use it
        if let keychainVal = KeychainHelper.load(key: key), !keychainVal.isEmpty {
            // Remove legacy plain-text key from UserDefaults if still present
            UserDefaults.standard.removeObject(forKey: key)
            return keychainVal
        }
        
        // 2. If present in UserDefaults (legacy), migrate to Keychain and wipe plain text
        if let legacyVal = UserDefaults.standard.string(forKey: key), !legacyVal.isEmpty {
            KeychainHelper.save(key: key, value: legacyVal)
            UserDefaults.standard.removeObject(forKey: key)
            return legacyVal
        }
        
        return ""
    }
    
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }
    
    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        await withTaskGroup(of: Void.self) { group in
            if enableCodex { group.addTask { await self.checkCodex() } } else { self.codexQuota = nil }
            if enableClaude { group.addTask { await self.checkClaude() } } else { self.claudeQuota = nil }
            if enableZai { group.addTask { await self.checkZai() } } else { self.zaiQuota = nil }
            if enableGemini { group.addTask { await self.checkGemini() } } else { self.geminiQuota = nil }
            if enableGrok { group.addTask { await self.checkGrok() } } else { self.grokQuota = nil }
            if enableOpenRouter { group.addTask { await self.checkOpenRouter() } } else { self.openRouterQuota = nil }
            if enableDeepSeek { group.addTask { await self.checkDeepSeek() } } else { self.deepSeekQuota = nil }
            if enableOllama { group.addTask { await self.checkOllama() } } else { self.ollamaQuota = nil }
            
            for provider in customProviders where provider.isEnabled {
                group.addTask {
                    let quota = await self.checkCustomProvider(provider)
                    await MainActor.run {
                        self.customQuotas[provider.id] = quota
                    }
                }
            }
        }
    }
    
    // MARK: - Timezone & Geo Localizer Helpers
    static func nextMidnight(timeZoneId: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        if let zone = TimeZone(identifier: timeZoneId) {
            cal.timeZone = zone
            let now = Date()
            let comp = cal.dateComponents([.year, .month, .day], from: now)
            if let startOfToday = cal.date(from: comp),
               let nextMidnight = cal.date(byAdding: .day, value: 1, to: startOfToday) {
                return nextMidnight
            }
        }
        return Date().addingTimeInterval(3600 * 6)
    }
    
    static func nextMidnightPacificTime() -> Date {
        return nextMidnight(timeZoneId: "America/Los_Angeles")
    }
    
    static func parseServerDate(_ value: Any?) -> Date? {
        if let d = value as? Date { return d }
        if let num = value as? Double {
            if num > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: num / 1000.0)
            } else if num > 1_000_000_000 {
                return Date(timeIntervalSince1970: num)
            }
        }
        if let num = value as? Int {
            if num > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: Double(num) / 1000.0)
            } else if num > 1_000_000_000 {
                return Date(timeIntervalSince1970: Double(num))
            }
        }
        guard let str = value as? String, !str.isEmpty else { return nil }
        
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }
        
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
            "HH:mm zzz",
            "HH:mm"
        ]
        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = df.date(from: str) {
                let comp = Calendar.current.dateComponents([.hour, .minute], from: d)
                var todayComp = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                todayComp.hour = comp.hour
                todayComp.minute = comp.minute
                todayComp.second = 0
                if let target = Calendar.current.date(from: todayComp) {
                    return target > Date() ? target : target.addingTimeInterval(86400)
                }
                return d
            }
        }
        
        if str.lowercased().contains("pacific") || str.lowercased().contains("pt") {
            return nextMidnight(timeZoneId: "America/Los_Angeles")
        }
        
        return nil
    }
    
    static func formatCountdown(until date: Date) -> String {
        let diff = date.timeIntervalSinceNow
        if diff <= 0 { return "сейчас" }
        let totalMinutes = max(1, Int(ceil(diff / 60.0)))
        let days = totalMinutes / 1440
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        if days > 0 {
            if hours > 0 { return "\(days)д \(hours)ч" }
            if minutes > 0 { return "\(days)д \(minutes)м" }
            return "\(days)д"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)ч \(minutes)м" : "\(hours)ч"
        }
        return "\(minutes)м"
    }
    
    static func formatLocalizedResetTime(date: Date) -> String {
        let now = Date()
        let diff = date.timeIntervalSince(now)
        let localFormatter = DateFormatter()
        localFormatter.timeZone = TimeZone.current
        localFormatter.locale = Locale(identifier: "ru_RU")
        localFormatter.dateFormat = "HH:mm"
        
        let timeStr = localFormatter.string(from: date)
        let totalMinutes = max(0, Int(diff) / 60)
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        
        if Calendar.current.isDateInToday(date) {
            if diff > 60 {
                if hours > 0 {
                    return "Сегодня в \(timeStr) (через \(hours)ч \(minutes)м)"
                } else {
                    return "Сегодня в \(timeStr) (через \(minutes)м)"
                }
            } else {
                return "Сегодня в \(timeStr) (сейчас)"
            }
        } else if Calendar.current.isDateInTomorrow(date) {
            if hours > 0 {
                return "Завтра в \(timeStr) (через \(hours)ч \(minutes)м)"
            } else {
                return "Завтра в \(timeStr)"
            }
        } else {
            localFormatter.dateFormat = "d MMMM в HH:mm"
            let dateStr = localFormatter.string(from: date)
            if days > 0 {
                if hours > 0 {
                    return "\(dateStr) (через \(days)д \(hours)ч)"
                } else {
                    return "\(dateStr) (через \(days)д)"
                }
            } else {
                return "\(dateStr) (через \(hours)ч)"
            }
        }
    }
    
    // MARK: - Clock & Alarm Integration
    func setAlarmForReset(quota: LLMQuotaInfo, targetResetDate: Date? = nil) {
        // Find earliest future resetDate among candidate windows or quota.resetDate
        let candidateDates = quota.windows.compactMap { $0.resetDate }.filter { $0 > Date() }
        let chosenDate: Date
        if let specific = targetResetDate, specific > Date() {
            chosenDate = specific
        } else if let earliest = candidateDates.min() {
            chosenDate = earliest
        } else if let qDate = quota.resetDate, qDate > Date() {
            chosenDate = qDate
        } else {
            // Default 3 hours if no explicit future date is found
            chosenDate = Date().addingTimeInterval(3600 * 3)
        }
        
        let localFormatter = DateFormatter()
        localFormatter.timeZone = TimeZone.current
        localFormatter.locale = Locale(identifier: "ru_RU")
        localFormatter.dateFormat = "HHmm"
        let hhmmStr = localFormatter.string(from: chosenDate)
        
        localFormatter.dateFormat = "HH:mm"
        let displayTimeStr = localFormatter.string(from: chosenDate)
        
        let diffSeconds = max(10, Int(chosenDate.timeIntervalSinceNow))
        let hoursLeft = max(1, Int(ceil(Double(diffSeconds) / 3600.0)))
        let alarmTitle = "Сброс лимита \(quota.providerName)"
        
        // 1. Set real Alarm in macOS Clock.app via UI Scripting
        let clockScript = """
        tell application "Clock"
            reopen
            activate
        end tell
        delay 0.5
        tell application "System Events"
            tell process "Clock"
                set frontmost to true
                try
                    click radio button 2 of radio group 1 of toolbar 1 of front window
                end try
                delay 0.25
                try
                    click menu button 1 of toolbar 1 of front window
                end try
                delay 0.35
                try
                    keystroke "\(hhmmStr)"
                    delay 0.2
                    set value of text field 1 of sheet 1 of front window to "\(alarmTitle)"
                    delay 0.2
                    try
                        click button "Сохранить" of sheet 1 of front window
                    on error
                        click button "Save" of sheet 1 of front window
                    end try
                end try
            end tell
        end tell
        """
        
        // 2. Set native reminder with alert & sound in Reminders as backup
        let remindersScript = """
        tell application "Reminders"
            set targetList to default list
            set alertDate to (current date) + \(diffSeconds)
            make new reminder at targetList with properties {name:"\(alarmTitle) (\(displayTimeStr))", remind me date:alertDate}
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeAppleScript(clockScript)
            self?.executeAppleScript(remindersScript)
        }
        
        // 3. Button feedback
        self.alarmSetItemId = quota.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.alarmSetItemId == quota.id {
                self?.alarmSetItemId = nil
            }
        }
    }
    
    nonisolated private func executeAppleScript(_ script: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
        proc.waitUntilExit()
    }
    
    // MARK: - Custom Provider Management
    func addCustomProvider(name: String = "Jev / Custom AI", baseUrl: String = "https://api.openai.com/v1", apiKey: String = "") {
        let new = CustomLLMProvider(name: name, baseUrl: baseUrl, apiKey: apiKey, isEnabled: true)
        customProviders.append(new)
        Task {
            let quota = await checkCustomProvider(new)
            self.customQuotas[new.id] = quota
        }
    }
    
    func removeCustomProvider(id: UUID) {
        customProviders.removeAll { $0.id == id }
        customQuotas.removeValue(forKey: id)
        KeychainHelper.delete(key: "custom_key_\(id)")
    }
    
    // MARK: - Preset 1: Codex / OpenAI
    private func checkCodex() async {
        let key = codexApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            codexQuota = LLMQuotaInfo(
                providerName: "Codex / OpenAI",
                planName: "Не подключен",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет ключа",
                detailText: "Добавьте ключ в настройках",
                isError: true
            )
            return
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    let resetDate = LLMTrackerManager.nextMidnightPacificTime()
                    let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
                    let window = LLMQuotaWindow(
                        title: "Дневной лимит (RPD)",
                        usedPercent: nil,
                        usageText: "Полночь PT",
                        resetDate: resetDate,
                        resetDescription: resetText
                    )
                    self.codexQuota = LLMQuotaInfo(
                        providerName: "Codex / OpenAI",
                        planName: "OpenAI API",
                        windows: [window],
                        resetDate: resetDate,
                        resetTimeDescription: resetText,
                        detailText: "API подключен"
                    )
                    return
                } else if http.statusCode == 401 {
                    self.codexQuota = LLMQuotaInfo(
                        providerName: "Codex / OpenAI",
                        planName: "Ошибка ключа",
                        windows: [],
                        resetDate: nil,
                        resetTimeDescription: "Неверный ключ",
                        detailText: "Проверьте API ключ",
                        isError: true
                    )
                    return
                }
            }
        } catch {
            self.codexQuota = LLMQuotaInfo(
                providerName: "Codex / OpenAI",
                planName: "Ошибка сети",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
            return
        }
        
        let resetDate = LLMTrackerManager.nextMidnightPacificTime()
        let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
        self.codexQuota = LLMQuotaInfo(
            providerName: "Codex / OpenAI",
            planName: "OpenAI API",
            windows: [LLMQuotaWindow(title: "Дневной лимит", usedPercent: nil, usageText: "Полночь PT", resetDate: resetDate, resetDescription: resetText)],
            resetDate: resetDate,
            resetTimeDescription: resetText,
            detailText: "Ключ сохранен"
        )
    }
    
    // MARK: - Preset 2: Claude
    private func checkClaude() async {
        // 1. Probe Antigravity Language Server for Claude and GPT models
        if let groups = await AntigravityProbe.probeLocalGroups(),
           let claudeGroup = groups.first(where: { $0.displayName.localizedCaseInsensitiveContains("claude") || $0.displayName.localizedCaseInsensitiveContains("gpt") }) {
            var parsedWindows: [LLMQuotaWindow] = []
            var earliestReset: Date? = nil
            
            for bucket in claudeGroup.buckets {
                let remPct = bucket.remainingFraction * 100.0
                var resetDesc: String? = nil
                if let rDate = bucket.resetTime {
                    resetDesc = "Resets in \(LLMTrackerManager.formatCountdown(until: rDate))"
                    if earliestReset == nil || rDate < earliestReset! {
                        earliestReset = rDate
                    }
                }
                
                parsedWindows.append(LLMQuotaWindow(
                    title: bucket.displayName,
                    usedPercent: max(0.0, min(100.0, 100.0 - remPct)),
                    remainingPercent: max(0.0, min(100.0, remPct)),
                    usageText: String(format: "%.0f%%", remPct),
                    resetDate: bucket.resetTime,
                    resetDescription: resetDesc
                ))
            }
            
            parsedWindows.sort { w1, w2 in
                if w1.title.contains("Five Hour") { return true }
                if w2.title.contains("Five Hour") { return false }
                return false
            }
            
            let resetSummary: String
            if let reset = earliestReset {
                resetSummary = "Resets in \(LLMTrackerManager.formatCountdown(until: reset))"
            } else {
                resetSummary = "Limits active"
            }
            
            self.claudeQuota = LLMQuotaInfo(
                providerName: "Claude",
                planName: claudeGroup.displayName,
                windows: parsedWindows,
                resetDate: earliestReset,
                resetTimeDescription: resetSummary,
                detailText: "Antigravity IDE квота",
                isError: false
            )
            return
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let statsPath = home.appendingPathComponent(".claude/stats-cache.json")
        if let data = try? Data(contentsOf: statsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let resetsAt = json["resets_at"] as? String,
               let utilization = json["utilization"] as? Double {
                let parsedDate = LLMTrackerManager.parseServerDate(resetsAt)
                let localDesc = parsedDate != nil ? LLMTrackerManager.formatLocalizedResetTime(date: parsedDate!) : "Сброс в \(resetsAt)"
                let pct = min(100.0, max(0.0, utilization * 100.0))
                
                let window = LLMQuotaWindow(
                    title: "Five Hour Limit Remaining",
                    usedPercent: pct,
                    remainingPercent: max(0.0, 100.0 - pct),
                    usageText: String(format: "%.0f%%", max(0.0, 100.0 - pct)),
                    resetDate: parsedDate,
                    resetDescription: localDesc
                )
                
                self.claudeQuota = LLMQuotaInfo(
                    providerName: "Claude",
                    planName: "Claude Code",
                    windows: [window],
                    resetDate: parsedDate,
                    resetTimeDescription: localDesc,
                    detailText: String(format: "%.1f%% использовано", pct)
                )
                return
            }
        }
        
        let token = claudeSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            let defaultReset = Date().addingTimeInterval(3600 * 5)
            let resetDesc = LLMTrackerManager.formatLocalizedResetTime(date: defaultReset)
            let window = LLMQuotaWindow(
                title: "Five Hour Limit Remaining",
                usedPercent: nil,
                remainingPercent: 100,
                usageText: "Сессия активна",
                resetDate: defaultReset,
                resetDescription: resetDesc
            )
            self.claudeQuota = LLMQuotaInfo(
                providerName: "Claude",
                planName: "Anthropic Session",
                windows: [window],
                resetDate: defaultReset,
                resetTimeDescription: resetDesc,
                detailText: "Токен сохранен"
            )
            return
        }
        
        self.claudeQuota = LLMQuotaInfo(
            providerName: "Claude",
            planName: "Не подключен",
            windows: [],
            resetDate: nil,
            resetTimeDescription: "Нужен CLI или токен",
            detailText: "Запустите claude в терминале",
            isError: true
        )
    }
    
    // MARK: - Preset 3: Z.ai (Zhipu / GLM / BigModel)
    private func checkZai() async {
        let key = zaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            zaiQuota = LLMQuotaInfo(
                providerName: "Z.ai",
                planName: "Не подключен",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет ключа",
                detailText: "Добавьте API ключ",
                isError: true
            )
            return
        }
        
        let host = key.contains(".") ? "https://open.bigmodel.cn" : "https://api.z.ai"
        guard let url = URL(string: "\(host)/api/monitor/usage/quota/limit") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success,
                       let dataDict = json["data"] as? [String: Any] {
                        
                        let planName = "Coding Plan"
                        var parsedWindows: [LLMQuotaWindow] = []
                        var earliestReset: Date? = nil
                        
                        if let limits = dataDict["limits"] as? [[String: Any]] {
                            for limit in limits {
                                let unit = limit["unit"] as? Int ?? 0
                                let number = limit["number"] as? Int ?? 1
                                let usage = limit["usage"] as? Int ?? 0
                                let currentValue = limit["currentValue"] as? Int ?? 0
                                let remainingRaw = limit["remaining"] as? Int
                                
                                let remaining: Int
                                if let r = remainingRaw {
                                    remaining = r
                                } else if usage > 0 {
                                    remaining = max(0, usage - currentValue)
                                } else {
                                    remaining = 0
                                }
                                
                                let remainingPercent: Double
                                if usage > 0 {
                                    remainingPercent = max(0.0, min(100.0, Double(remaining) / Double(usage) * 100.0))
                                } else {
                                    let rawPct = limit["percentage"] as? Double ?? 0.0
                                    remainingPercent = max(0.0, min(100.0, 100.0 - rawPct))
                                }
                                
                                var windowTitle = "Limit"
                                if unit == 3 || (unit == 5 && number == 300) {
                                    windowTitle = "Five Hour Limit Remaining"
                                } else if unit == 6 || (unit == 1 && number == 7) {
                                    windowTitle = "Weekly Limit Remaining"
                                } else if unit == 1 {
                                    windowTitle = "Daily Limit Remaining"
                                } else {
                                    windowTitle = "Limit (\(number))"
                                }
                                
                                var resetDate: Date? = nil
                                var resetDesc: String? = nil
                                if let nextResetTime = limit["nextResetTime"] {
                                    if let date = LLMTrackerManager.parseServerDate(nextResetTime) {
                                        resetDate = date
                                        resetDesc = "Resets in \(LLMTrackerManager.formatCountdown(until: date))"
                                        if earliestReset == nil || date < earliestReset! {
                                            earliestReset = date
                                        }
                                    }
                                }
                                
                                let usageText = "\(remaining.formattedWithSeparator()) / \(usage.formattedWithSeparator())"
                                
                                parsedWindows.append(LLMQuotaWindow(
                                    title: windowTitle,
                                    usedPercent: 100.0 - remainingPercent,
                                    remainingPercent: remainingPercent,
                                    usageText: usageText,
                                    resetDate: resetDate,
                                    resetDescription: resetDesc
                                ))
                            }
                        }
                        
                        // Sort: Five Hour first, then Weekly
                        parsedWindows.sort { w1, w2 in
                            if w1.title.contains("Five Hour") { return true }
                            if w2.title.contains("Five Hour") { return false }
                            return false
                        }
                        
                        let resetSummary: String
                        if let reset = earliestReset {
                            resetSummary = "Resets in \(LLMTrackerManager.formatCountdown(until: reset))"
                        } else {
                            resetSummary = "Limits active"
                        }
                        
                        self.zaiQuota = LLMQuotaInfo(
                            providerName: "Z.ai",
                            planName: planName,
                            windows: parsedWindows,
                            resetDate: earliestReset,
                            resetTimeDescription: resetSummary,
                            detailText: "Кредиты активны",
                            isError: false
                        )
                        return
                    }
                } else if http.statusCode == 401 || http.statusCode == 403 {
                    self.zaiQuota = LLMQuotaInfo(
                        providerName: "Z.ai",
                        planName: "Ошибка авторизации",
                        windows: [],
                        resetDate: nil,
                        resetTimeDescription: "Неверный ключ",
                        detailText: "Проверьте API ключ",
                        isError: true
                    )
                    return
                }
            }
        } catch {
            self.zaiQuota = LLMQuotaInfo(
                providerName: "Z.ai",
                planName: "Сетевая ошибка",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
            return
        }
        
        self.zaiQuota = LLMQuotaInfo(
            providerName: "Z.ai",
            planName: "Coding Plan",
            windows: [],
            resetDate: nil,
            resetTimeDescription: "Подключено",
            detailText: "Ключ сохранен"
        )
    }
    
    // MARK: - Preset 4: Gemini (Antigravity Local + AI Studio Fallback)
    private func checkGemini() async {
        // 1. Probe local Antigravity Language Server for Gemini Models
        if let groups = await AntigravityProbe.probeLocalGroups(),
           let geminiGroup = groups.first(where: { $0.displayName.localizedCaseInsensitiveContains("gemini") }) {
            var parsedWindows: [LLMQuotaWindow] = []
            var earliestReset: Date? = nil
            
            for bucket in geminiGroup.buckets {
                let remPct = bucket.remainingFraction * 100.0
                var resetDesc: String? = nil
                if let rDate = bucket.resetTime {
                    resetDesc = "Resets in \(LLMTrackerManager.formatCountdown(until: rDate))"
                    if earliestReset == nil || rDate < earliestReset! {
                        earliestReset = rDate
                    }
                }
                
                parsedWindows.append(LLMQuotaWindow(
                    title: bucket.displayName,
                    usedPercent: max(0.0, min(100.0, 100.0 - remPct)),
                    remainingPercent: max(0.0, min(100.0, remPct)),
                    usageText: String(format: "%.0f%%", remPct),
                    resetDate: bucket.resetTime,
                    resetDescription: resetDesc
                ))
            }
            
            // Sort: Five Hour first, then Weekly
            parsedWindows.sort { w1, w2 in
                if w1.title.contains("Five Hour") { return true }
                if w2.title.contains("Five Hour") { return false }
                return false
            }
            
            let resetSummary: String
            if let reset = earliestReset {
                resetSummary = "Resets in \(LLMTrackerManager.formatCountdown(until: reset))"
            } else {
                resetSummary = "Limits active"
            }
            
            self.geminiQuota = LLMQuotaInfo(
                providerName: "Gemini",
                planName: geminiGroup.displayName, // "Gemini Models"
                windows: parsedWindows,
                resetDate: earliestReset,
                resetTimeDescription: resetSummary,
                detailText: "Antigravity IDE квота",
                isError: false
            )
            return
        }
        
        let key = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            geminiQuota = LLMQuotaInfo(
                providerName: "Gemini",
                planName: "Не подключен",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Запустите Antigravity или введите ключ",
                detailText: "В Antigravity квоты отслеживаются автоматически",
                isError: true
            )
            return
        }
        
        // Fast probe to verify key without fetching model lists
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1&key=\(key)") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    let resetDate = LLMTrackerManager.nextMidnight(timeZoneId: "America/Los_Angeles")
                    let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
                    
                    let dayWindow = LLMQuotaWindow(
                        title: "Daily Limit Remaining",
                        usedPercent: 0,
                        remainingPercent: 100,
                        usageText: "1 500 RPD",
                        resetDate: resetDate,
                        resetDescription: resetText
                    )
                    
                    self.geminiQuota = LLMQuotaInfo(
                        providerName: "Gemini",
                        planName: "Google AI Studio",
                        windows: [dayWindow],
                        resetDate: resetDate,
                        resetTimeDescription: resetText,
                        detailText: "AI Studio подключен"
                    )
                    return
                } else if http.statusCode == 400 || http.statusCode == 403 {
                    self.geminiQuota = LLMQuotaInfo(
                        providerName: "Gemini",
                        planName: "Ошибка ключа",
                        windows: [],
                        resetDate: nil,
                        resetTimeDescription: "Неверный ключ",
                        detailText: "Проверьте AI Studio ключ",
                        isError: true
                    )
                    return
                }
            }
        } catch {
            self.geminiQuota = LLMQuotaInfo(
                providerName: "Gemini",
                planName: "Сетевая ошибка",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
            return
        }
        
        let resetDate = LLMTrackerManager.nextMidnight(timeZoneId: "America/Los_Angeles")
        let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
        self.geminiQuota = LLMQuotaInfo(
            providerName: "Gemini",
            planName: "Google AI Studio",
            windows: [
                LLMQuotaWindow(title: "Daily Limit Remaining", usedPercent: 0, remainingPercent: 100, usageText: "1 500 RPD", resetDate: resetDate, resetDescription: resetText)
            ],
            resetDate: resetDate,
            resetTimeDescription: resetText,
            detailText: "Ключ сохранен"
        )
    }
    
    // MARK: - Preset 5: Grok (xAI)
    private func checkGrok() async {
        let key = grokApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            grokQuota = LLMQuotaInfo(
                providerName: "Grok (xAI)",
                planName: "Не подключен",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет ключа",
                detailText: "Добавьте xAI ключ в настройках",
                isError: true
            )
            return
        }
        
        guard let url = URL(string: "https://api.x.ai/v1/models") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    let resetDate = LLMTrackerManager.nextMidnightPacificTime()
                    let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
                    let window = LLMQuotaWindow(
                        title: "Дневной лимит",
                        usedPercent: nil,
                        usageText: "Полночь PT",
                        resetDate: resetDate,
                        resetDescription: resetText
                    )
                    self.grokQuota = LLMQuotaInfo(
                        providerName: "Grok (xAI)",
                        planName: "xAI API",
                        windows: [window],
                        resetDate: resetDate,
                        resetTimeDescription: resetText,
                        detailText: "API подключен"
                    )
                    return
                } else if http.statusCode == 401 || http.statusCode == 403 {
                    self.grokQuota = LLMQuotaInfo(
                        providerName: "Grok (xAI)",
                        planName: "Ошибка ключа",
                        windows: [],
                        resetDate: nil,
                        resetTimeDescription: "Неверный ключ",
                        detailText: "Проверьте xAI API ключ",
                        isError: true
                    )
                    return
                }
            }
        } catch {
            self.grokQuota = LLMQuotaInfo(
                providerName: "Grok (xAI)",
                planName: "Сетевая ошибка",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
            return
        }
        
        let resetDate = LLMTrackerManager.nextMidnightPacificTime()
        let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
        self.grokQuota = LLMQuotaInfo(
            providerName: "Grok (xAI)",
            planName: "xAI API",
            windows: [LLMQuotaWindow(title: "Дневной лимит", usedPercent: nil, usageText: "Полночь PT", resetDate: resetDate, resetDescription: resetText)],
            resetDate: resetDate,
            resetTimeDescription: resetText,
            detailText: "Ключ сохранен"
        )
    }
    
    // MARK: - Preset 6: OpenRouter
    private func checkOpenRouter() async {
        let key = openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            openRouterQuota = LLMQuotaInfo(
                providerName: "OpenRouter",
                planName: "Не подключен",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет ключа",
                detailText: "Добавьте ключ в настройках",
                isError: true
            )
            return
        }
        guard let url = URL(string: "https://openrouter.ai/api/v1/auth/key") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any] {
                    let usage = (dataDict["usage"] as? Double) ?? 0.0
                    let limit = (dataDict["limit"] as? Double) ?? 0.0
                    let label = (dataDict["label"] as? String) ?? "Key"
                    
                    let remaining = max(0, limit - usage)
                    let pct = limit > 0 ? min(100.0, (usage / limit) * 100.0) : 0.0
                    let resetDate = LLMTrackerManager.nextMidnightPacificTime()
                    
                    let window = LLMQuotaWindow(
                        title: "Баланс кредитов",
                        usedPercent: pct,
                        usageText: String(format: "$%.2f / $%.2f", usage, limit),
                        resetDate: resetDate,
                        resetDescription: String(format: "$%.2f доступно", remaining)
                    )
                    
                    self.openRouterQuota = LLMQuotaInfo(
                        providerName: "OpenRouter",
                        planName: label,
                        windows: [window],
                        resetDate: resetDate,
                        resetTimeDescription: String(format: "$%.2f осталось", remaining),
                        detailText: String(format: "Использовано $%.2f из $%.2f", usage, limit)
                    )
                    return
                }
            }
            self.openRouterQuota = LLMQuotaInfo(
                providerName: "OpenRouter",
                planName: "Ошибка ключа",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Неверный ключ",
                detailText: "Проверьте API ключ",
                isError: true
            )
        } catch {
            self.openRouterQuota = LLMQuotaInfo(
                providerName: "OpenRouter",
                planName: "Сетевая ошибка",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
        }
    }
    
    // MARK: - Preset 7: DeepSeek
    private func checkDeepSeek() async {
        let key = deepSeekApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            deepSeekQuota = LLMQuotaInfo(
                providerName: "DeepSeek",
                planName: "Не подключен",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет ключа",
                detailText: "Добавьте ключ в настройках",
                isError: true
            )
            return
        }
        guard let url = URL(string: "https://api.deepseek.com/user/balance") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isAvailable = json["is_available"] as? Bool, isAvailable,
                   let balanceInfos = json["balance_infos"] as? [[String: Any]],
                   let first = balanceInfos.first {
                    let totalBalance = (first["total_balance"] as? String) ?? "0"
                    let currency = (first["currency"] as? String) ?? "USD"
                    
                    let window = LLMQuotaWindow(
                        title: "Баланс аккаунта",
                        usedPercent: 0,
                        usageText: "\(totalBalance) \(currency)",
                        resetDate: nil,
                        resetDescription: "Пополняемый баланс"
                    )
                    
                    self.deepSeekQuota = LLMQuotaInfo(
                        providerName: "DeepSeek",
                        planName: "Pay-as-you-go",
                        windows: [window],
                        resetDate: nil,
                        resetTimeDescription: "\(totalBalance) \(currency)",
                        detailText: "Баланс активен"
                    )
                    return
                }
            }
            self.deepSeekQuota = LLMQuotaInfo(
                providerName: "DeepSeek",
                planName: "Ошибка ключа",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Неверный ключ",
                detailText: "Проверьте ключ",
                isError: true
            )
        } catch {
            self.deepSeekQuota = LLMQuotaInfo(
                providerName: "DeepSeek",
                planName: "Сетевая ошибка",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
        }
    }
    
    // MARK: - Preset 8: Ollama Local
    private func checkOllama() async {
        guard let url = URL(string: "\(ollamaHost)/api/tags") else { return }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let window = LLMQuotaWindow(
                    title: "Локальный инференс",
                    usedPercent: 0,
                    usageText: "Без лимитов",
                    resetDate: nil,
                    resetDescription: "Запуск на устройстве"
                )
                self.ollamaQuota = LLMQuotaInfo(
                    providerName: "Ollama Local",
                    planName: "Localhost",
                    windows: [window],
                    resetDate: nil,
                    resetTimeDescription: "Онлайн",
                    detailText: "Сервер работает"
                )
                return
            }
        } catch {}
        
        self.ollamaQuota = LLMQuotaInfo(
            providerName: "Ollama Local",
            planName: "Недоступен",
            windows: [],
            resetDate: nil,
            resetTimeDescription: "Офлайн",
            detailText: "Хост недоступен",
            isError: true
        )
    }
    
    // MARK: - Universal Custom Provider Checker
    private func checkCustomProvider(_ provider: CustomLLMProvider) async -> LLMQuotaInfo {
        let rawUrl = provider.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: rawUrl) else {
            return LLMQuotaInfo(
                providerName: provider.name,
                planName: "Ошибка URL",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Неверный URL",
                detailText: "Проверьте адрес",
                isError: true
            )
        }
        
        var modelsUrl = parsed
        if !rawUrl.hasSuffix("/models") {
            if rawUrl.hasSuffix("/") {
                modelsUrl = URL(string: "\(rawUrl)models") ?? parsed
            } else if rawUrl.hasSuffix("/v1") {
                modelsUrl = URL(string: "\(rawUrl)/models") ?? parsed
            } else {
                modelsUrl = URL(string: "\(rawUrl)/v1/models") ?? parsed
            }
        }
        
        var req = URLRequest(url: modelsUrl)
        req.timeoutInterval = 8
        let key = provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let dataDict = json["data"] as? [String: Any],
                           let usage = dataDict["usage"] as? Double,
                           let limit = dataDict["limit"] as? Double {
                            let remaining = max(0, limit - usage)
                            let pct = limit > 0 ? min(100.0, (usage / limit) * 100.0) : 0.0
                            let resetDate = LLMTrackerManager.nextMidnightPacificTime()
                            let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
                            let window = LLMQuotaWindow(
                                title: "Баланс квоты",
                                usedPercent: pct,
                                usageText: String(format: "$%.2f / $%.2f", usage, limit),
                                resetDate: resetDate,
                                resetDescription: String(format: "$%.2f доступно", remaining)
                            )
                            return LLMQuotaInfo(
                                providerName: provider.name,
                                planName: "Custom API",
                                windows: [window],
                                resetDate: resetDate,
                                resetTimeDescription: resetText,
                                detailText: String(format: "Использовано $%.2f из $%.2f", usage, limit)
                            )
                        }
                    }
                    
                    let resetDate = LLMTrackerManager.nextMidnightPacificTime()
                    let resetText = LLMTrackerManager.formatLocalizedResetTime(date: resetDate)
                    let window = LLMQuotaWindow(
                        title: "Статус квоты",
                        usedPercent: 0,
                        usageText: "Подключено",
                        resetDate: resetDate,
                        resetDescription: resetText
                    )
                    return LLMQuotaInfo(
                        providerName: provider.name,
                        planName: "Custom Proxy",
                        windows: [window],
                        resetDate: resetDate,
                        resetTimeDescription: "Онлайн",
                        detailText: "Эндпоинт активен"
                    )
                } else if http.statusCode == 401 || http.statusCode == 403 {
                    return LLMQuotaInfo(
                        providerName: provider.name,
                        planName: "Ошибка доступа",
                        windows: [],
                        resetDate: nil,
                        resetTimeDescription: "Неверный ключ",
                        detailText: "HTTP \(http.statusCode)",
                        isError: true
                    )
                } else {
                    return LLMQuotaInfo(
                        providerName: provider.name,
                        planName: "HTTP \(http.statusCode)",
                        windows: [],
                        resetDate: nil,
                        resetTimeDescription: "Ошибка сервера",
                        detailText: "Статус \(http.statusCode)",
                        isError: true
                    )
                }
            }
        } catch {
            return LLMQuotaInfo(
                providerName: provider.name,
                planName: "Сетевая ошибка",
                windows: [],
                resetDate: nil,
                resetTimeDescription: "Нет связи",
                detailText: error.localizedDescription,
                isError: true
            )
        }
        
        return LLMQuotaInfo(
            providerName: provider.name,
            planName: "Неизвестно",
            windows: [],
            resetDate: nil,
            resetTimeDescription: "Офлайн",
            detailText: "Не удалось подключиться",
            isError: true
        )
    }
    
    // MARK: - Active Quotas
    var activeQuotas: [LLMQuotaInfo] {
        var list: [LLMQuotaInfo] = []
        if let q = codexQuota { list.append(q) }
        if let q = claudeQuota { list.append(q) }
        if let q = zaiQuota { list.append(q) }
        if let q = geminiQuota { list.append(q) }
        if let q = grokQuota { list.append(q) }
        if let q = openRouterQuota { list.append(q) }
        if let q = deepSeekQuota { list.append(q) }
        if let q = ollamaQuota { list.append(q) }
        
        for provider in customProviders where provider.isEnabled {
            if let q = customQuotas[provider.id] {
                list.append(q)
            }
        }
        return list
    }
    
    var topQuotaSummary: (percent: Double, color: Color)? {
        for q in activeQuotas {
            if let p = q.utilizationPercent, !q.isError {
                return (p, q.statusColor)
            }
        }
        return nil
    }
}
