import SwiftUI
import AppKit

enum TargetBrowser: String, CaseIterable, Identifiable {
    case defaultBrowser = "System Default"
    case safari = "Safari"
    case chrome = "Google Chrome"
    case brave = "Brave"
    case arc = "Arc"
    case firefox = "Firefox"
    
    var id: String { rawValue }
    
    var bundleIdentifier: String? {
        switch self {
        case .defaultBrowser: return nil
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .brave: return "com.brave.Browser"
        case .arc: return "company.thebrowser.Browser"
        case .firefox: return "org.mozilla.firefox"
        }
    }
    
    var appName: String {
        switch self {
        case .defaultBrowser: return "Safari"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .brave: return "Brave Browser"
        case .arc: return "Arc"
        case .firefox: return "Firefox"
        }
    }
}

enum OpenTargetMode: String, CaseIterable, Identifiable {
    case newTab = "New Tab"
    case newWindow = "New Window"
    
    var id: String { rawValue }
    
    @MainActor
    var localizedTitle: String {
        switch self {
        case .newTab: return loc("New Tab", "Вкладка")
        case .newWindow: return loc("New Window", "Окно")
        }
    }
}

struct WebToolItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var url: String
    var iconName: String
    var colorName: String // "blue", "purple", "orange", "green", "red", "teal"
    var useCustomFavicon: Bool = false
    var faviconImageData: Data? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, iconName, colorName, useCustomFavicon, faviconImageData
    }
    
    init(id: UUID = UUID(), title: String, url: String, iconName: String, colorName: String, useCustomFavicon: Bool = false, faviconImageData: Data? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.iconName = iconName
        self.colorName = colorName
        self.useCustomFavicon = useCustomFavicon
        self.faviconImageData = faviconImageData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decode(String.self, forKey: .url)
        self.iconName = try container.decode(String.self, forKey: .iconName)
        self.colorName = try container.decode(String.self, forKey: .colorName)
        self.useCustomFavicon = try container.decodeIfPresent(Bool.self, forKey: .useCustomFavicon) ?? false
        self.faviconImageData = try container.decodeIfPresent(Data.self, forKey: .faviconImageData)
    }
    
    var displayColor: Color {
        switch colorName.lowercased() {
        case "white": return .white
        case "blue": return .blue
        case "red": return .red
        case "yellow": return .yellow
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        default: return .white
        }
    }
}

@MainActor
class WebToolsManager: ObservableObject {
    static let shared = WebToolsManager()
    
    @Published var items: [WebToolItem] = []
    
    @Published var selectedBrowser: TargetBrowser = {
        let saved = UserDefaults.standard.string(forKey: "WebToolsTargetBrowser") ?? TargetBrowser.defaultBrowser.rawValue
        return TargetBrowser(rawValue: saved) ?? .defaultBrowser
    }() {
        didSet {
            UserDefaults.standard.set(selectedBrowser.rawValue, forKey: "WebToolsTargetBrowser")
        }
    }
    
    @Published var openMode: OpenTargetMode = {
        let saved = UserDefaults.standard.string(forKey: "WebToolsOpenMode") ?? OpenTargetMode.newTab.rawValue
        return OpenTargetMode(rawValue: saved) ?? .newTab
    }() {
        didSet {
            UserDefaults.standard.set(openMode.rawValue, forKey: "WebToolsOpenMode")
        }
    }
    
    init() {
        loadItems()
    }
    
    func loadItems() {
        if let data = UserDefaults.standard.data(forKey: "WebToolsItems"),
           var decoded = try? JSONDecoder().decode([WebToolItem].self, from: data) {
            if !UserDefaults.standard.bool(forKey: "WebToolsWhiteIconsV1") {
                for i in 0..<decoded.count {
                    decoded[i].colorName = "white"
                }
                UserDefaults.standard.set(true, forKey: "WebToolsWhiteIconsV1")
            }
            self.items = decoded
            saveItems()
        } else {
            // Default presets tailored for developer (Pure White HeroDock style)
            self.items = [
                WebToolItem(title: "Dev Server", url: "http://localhost:3000", iconName: "network", colorName: "white"),
                WebToolItem(title: "GitHub", url: "https://github.com", iconName: "chevron.left.forwardslash.chevron.right", colorName: "white"),
                WebToolItem(title: "ChatGPT", url: "https://chatgpt.com", iconName: "sparkles", colorName: "white"),
                WebToolItem(title: "Claude AI", url: "https://claude.ai", iconName: "brain.head.profile", colorName: "white"),
                WebToolItem(title: "Vercel", url: "https://vercel.com", iconName: "triangle.fill", colorName: "white")
            ]
            saveItems()
        }
    }
    
    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "WebToolsItems")
        }
    }
    
    func fetchFavicon(for urlString: String) async -> Data? {
        var clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "https://" + clean
        }
        guard let url = URL(string: clean), let host = url.host, !host.isEmpty else { return nil }
        
        // 1. Google Favicon Service (sz=128 gives crisp retina icons)
        if let gUrl = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128"),
           let (data, res) = try? await URLSession.shared.data(from: gUrl),
           let http = res as? HTTPURLResponse, http.statusCode == 200,
           data.count > 100 {
            return data
        }
        
        // 2. Direct /favicon.ico fallback
        let directStr = clean.hasSuffix("/") ? "\(clean)favicon.ico" : "\(clean)/favicon.ico"
        if let directUrl = URL(string: directStr),
           let (data, res) = try? await URLSession.shared.data(from: directUrl),
           let http = res as? HTTPURLResponse, http.statusCode == 200,
           data.count > 50 {
            return data
        }
        
        return nil
    }
    
    func addItem(title: String, url: String, iconName: String, colorName: String, useCustomFavicon: Bool = false) {
        var cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUrl.lowercased().hasPrefix("http://") && !cleanUrl.lowercased().hasPrefix("https://") {
            cleanUrl = "https://" + cleanUrl
        }
        let newItem = WebToolItem(
            id: UUID(),
            title: title.isEmpty ? "Web App" : title,
            url: cleanUrl,
            iconName: iconName.isEmpty ? "globe" : iconName,
            colorName: colorName,
            useCustomFavicon: useCustomFavicon,
            faviconImageData: nil
        )
        items.append(newItem)
        saveItems()
        
        if useCustomFavicon {
            let itemId = newItem.id
            Task {
                if let data = await self.fetchFavicon(for: cleanUrl) {
                    await MainActor.run {
                        if let idx = self.items.firstIndex(where: { $0.id == itemId }) {
                            self.items[idx].faviconImageData = data
                            self.saveItems()
                        }
                    }
                }
            }
        }
    }
    
    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }
    
    func open(item: WebToolItem) {
        guard let url = URL(string: item.url) else { return }
        
        let browser = selectedBrowser
        let mode = openMode
        
        // 1. If System Default browser
        if browser == .defaultBrowser {
            if mode == .newWindow {
                // Open new window via open -n
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-n", item.url]
                try? process.run()
            } else {
                // Open in default browser (new tab by default)
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        // 2. Specific Browser with AppleScript for guaranteed Tab vs Window control
        let appName = browser.appName
        let urlString = item.url
        
        var scriptSource = ""
        if browser == .safari {
            if mode == .newWindow {
                scriptSource = """
                tell application "Safari"
                    activate
                    make new document with properties {URL:"\(urlString)"}
                end tell
                """
            } else {
                scriptSource = """
                tell application "Safari"
                    activate
                    if (count of windows) is 0 then
                        make new document with properties {URL:"\(urlString)"}
                    else
                        tell front window
                            set current tab to (make new tab with properties {URL:"\(urlString)"})
                        end tell
                    end if
                end tell
                """
            }
        } else {
            // Chrome, Brave, Arc, Edge syntax
            if mode == .newWindow {
                scriptSource = """
                tell application "\(appName)"
                    activate
                    make new window
                    set URL of active tab of front window to "\(urlString)"
                end tell
                """
            } else {
                scriptSource = """
                tell application "\(appName)"
                    activate
                    if (count of windows) is 0 then
                        make new window
                        set URL of active tab of front window to "\(urlString)"
                    else
                        tell front window
                            make new tab with properties {URL:"\(urlString)"}
                        end tell
                    end if
                end tell
                """
            }
        }
        
        // Run AppleScript, fallback to NSWorkspace if script fails
        if let script = NSAppleScript(source: scriptSource) {
            var errorDict: NSDictionary?
            script.executeAndReturnError(&errorDict)
            if errorDict != nil {
                if let bundleId = browser.bundleIdentifier {
                    NSWorkspace.shared.open([url], withAppBundleIdentifier: bundleId, options: [], additionalEventParamDescriptor: nil, launchIdentifiers: nil)
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
