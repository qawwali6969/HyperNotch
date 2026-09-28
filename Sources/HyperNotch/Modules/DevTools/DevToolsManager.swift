import SwiftUI
import Foundation
import Network
import Combine

struct DevPortInfo: Identifiable, Equatable {
    let id: Int // Port number
    let serviceName: String
    var isOpen: Bool
}

struct DevToolsProvider: Identifiable, Equatable {
    let id: String // "zai", "gemini", "deepseek", "claude", "codex", "grok", "openrouter", "ollama", "custom_..."
    let name: String
    let shortName: String
    let icon: String
    let defaultModelId: String
}

struct LLMModelPricing: Identifiable, Equatable, Codable {
    let id: String
    let providerKey: String
    let providerName: String
    let modelName: String
    let shortName: String
    let inputCostPerMillion: Double
    let isFree: Bool
    
    var displayNameWithPrice: String {
        if isFree {
            return "\(modelName) (Free)"
        }
        return "\(modelName) ($\(String(format: "%.2f", inputCostPerMillion))/1M)"
    }
    
    func cost(for tokens: Int) -> Double {
        return (Double(tokens) / 1_000_000.0) * inputCostPerMillion
    }
    
    func formattedCost(tokens: Int) -> String {
        if isFree { return "$0.00 (Free)" }
        let c = cost(for: tokens)
        if c == 0 { return "$0.00" }
        if c < 0.00001 { return "<$0.00001" }
        return String(format: "$%.5f", c)
    }
    
    static func fallback(for providerKey: String) -> LLMModelPricing {
        if let found = catalog.first(where: { $0.providerKey == providerKey }) {
            return found
        }
        return catalog[0]
    }
    
    static let catalog: [LLMModelPricing] = [
        // Z.ai (Zhipu BigModel / GLM-4)
        LLMModelPricing(id: "glm-4-plus", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 Plus", shortName: "GLM-4 PLUS", inputCostPerMillion: 0.70, isFree: false),
        LLMModelPricing(id: "glm-4-0520", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 (0520)", shortName: "GLM-4", inputCostPerMillion: 0.70, isFree: false),
        LLMModelPricing(id: "glm-4-air", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 Air", shortName: "GLM AIR", inputCostPerMillion: 0.14, isFree: false),
        LLMModelPricing(id: "glm-4-airx", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 AirX", shortName: "GLM AIRX", inputCostPerMillion: 0.70, isFree: false),
        LLMModelPricing(id: "glm-4-flash", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 Flash", shortName: "GLM FLASH", inputCostPerMillion: 0.0, isFree: true),
        LLMModelPricing(id: "glm-4-flashx", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 FlashX", shortName: "GLM FLASHX", inputCostPerMillion: 0.015, isFree: false),
        LLMModelPricing(id: "glm-4-long", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 Long (1M)", shortName: "GLM LONG", inputCostPerMillion: 0.14, isFree: false),
        LLMModelPricing(id: "glm-zero-preview", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-Zero-Preview", shortName: "GLM ZERO", inputCostPerMillion: 0.70, isFree: false),
        LLMModelPricing(id: "codegeex-4", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "CodeGeeX-4", shortName: "CODEGEEX-4", inputCostPerMillion: 0.14, isFree: false),
        LLMModelPricing(id: "cogview-3-plus", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "CogView-3 Plus", shortName: "COGVIEW-3", inputCostPerMillion: 2.00, isFree: false),
        
        // Google Gemini
        LLMModelPricing(id: "gemini-2.0-flash", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 2.0 Flash", shortName: "2.0 FLASH", inputCostPerMillion: 0.10, isFree: true),
        LLMModelPricing(id: "gemini-2.0-flash-lite", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 2.0 Flash-Lite", shortName: "2.0 LITE", inputCostPerMillion: 0.075, isFree: true),
        LLMModelPricing(id: "gemini-2.0-pro-exp-02-05", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 2.0 Pro Exp", shortName: "2.0 PRO", inputCostPerMillion: 0.0, isFree: true),
        LLMModelPricing(id: "gemini-2.0-flash-thinking-exp", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 2.0 Flash Thinking", shortName: "2.0 THINK", inputCostPerMillion: 0.0, isFree: true),
        LLMModelPricing(id: "gemini-1.5-pro", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 1.5 Pro", shortName: "1.5 PRO", inputCostPerMillion: 1.25, isFree: false),
        LLMModelPricing(id: "gemini-1.5-flash", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 1.5 Flash", shortName: "1.5 FLASH", inputCostPerMillion: 0.075, isFree: false),
        LLMModelPricing(id: "gemini-1.5-flash-8b", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 1.5 Flash-8B", shortName: "1.5 FLASH-8B", inputCostPerMillion: 0.0375, isFree: false),
        
        // DeepSeek
        LLMModelPricing(id: "deepseek-v3", providerKey: "deepseek", providerName: "DeepSeek", modelName: "DeepSeek V3", shortName: "DEEPSEEK V3", inputCostPerMillion: 0.14, isFree: false),
        LLMModelPricing(id: "deepseek-r1", providerKey: "deepseek", providerName: "DeepSeek", modelName: "DeepSeek R1", shortName: "DEEPSEEK R1", inputCostPerMillion: 0.55, isFree: false),
        
        // Anthropic Claude
        LLMModelPricing(id: "claude-3-7-sonnet", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.7 Sonnet", shortName: "CLAUDE 3.7", inputCostPerMillion: 3.00, isFree: false),
        LLMModelPricing(id: "claude-3-7-sonnet-thinking", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.7 (Thinking)", shortName: "3.7 THINK", inputCostPerMillion: 3.00, isFree: false),
        LLMModelPricing(id: "claude-3-5-sonnet", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.5 Sonnet", shortName: "CLAUDE 3.5", inputCostPerMillion: 3.00, isFree: false),
        LLMModelPricing(id: "claude-3-5-haiku", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.5 Haiku", shortName: "CLAUDE HAIKU", inputCostPerMillion: 0.80, isFree: false),
        LLMModelPricing(id: "claude-3-opus", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3 Opus", shortName: "CLAUDE OPUS", inputCostPerMillion: 15.00, isFree: false),
        
        // OpenAI
        LLMModelPricing(id: "gpt-4o", providerKey: "codex", providerName: "OpenAI", modelName: "GPT-4o", shortName: "GPT-4O", inputCostPerMillion: 2.50, isFree: false),
        LLMModelPricing(id: "gpt-4o-mini", providerKey: "codex", providerName: "OpenAI", modelName: "GPT-4o mini", shortName: "GPT-4O MINI", inputCostPerMillion: 0.15, isFree: false),
        LLMModelPricing(id: "o3-mini", providerKey: "codex", providerName: "OpenAI", modelName: "o3-mini", shortName: "O3-MINI", inputCostPerMillion: 1.10, isFree: false),
        LLMModelPricing(id: "o1", providerKey: "codex", providerName: "OpenAI", modelName: "o1", shortName: "O1", inputCostPerMillion: 15.00, isFree: false),
        LLMModelPricing(id: "o1-mini", providerKey: "codex", providerName: "OpenAI", modelName: "o1-mini", shortName: "O1-MINI", inputCostPerMillion: 1.10, isFree: false),
        LLMModelPricing(id: "gpt-4-turbo", providerKey: "codex", providerName: "OpenAI", modelName: "GPT-4 Turbo", shortName: "GPT-4T", inputCostPerMillion: 10.00, isFree: false),
        LLMModelPricing(id: "gpt-3.5-turbo", providerKey: "codex", providerName: "OpenAI", modelName: "GPT-3.5 Turbo", shortName: "GPT-3.5", inputCostPerMillion: 0.50, isFree: false),
        
        // xAI Grok
        LLMModelPricing(id: "grok-2", providerKey: "grok", providerName: "xAI Grok", modelName: "Grok 2", shortName: "GROK 2", inputCostPerMillion: 2.00, isFree: false),
        LLMModelPricing(id: "grok-2-vision", providerKey: "grok", providerName: "xAI Grok", modelName: "Grok 2 Vision", shortName: "GROK VISION", inputCostPerMillion: 2.00, isFree: false),
        LLMModelPricing(id: "grok-beta", providerKey: "grok", providerName: "xAI Grok", modelName: "Grok Beta", shortName: "GROK BETA", inputCostPerMillion: 5.00, isFree: false),
        
        // OpenRouter
        LLMModelPricing(id: "deepseek/deepseek-r1", providerKey: "openrouter", providerName: "OpenRouter", modelName: "DeepSeek R1 (OR)", shortName: "R1 (OR)", inputCostPerMillion: 0.55, isFree: false),
        LLMModelPricing(id: "deepseek/deepseek-chat", providerKey: "openrouter", providerName: "OpenRouter", modelName: "DeepSeek V3 (OR)", shortName: "V3 (OR)", inputCostPerMillion: 0.14, isFree: false),
        LLMModelPricing(id: "anthropic/claude-3.7-sonnet", providerKey: "openrouter", providerName: "OpenRouter", modelName: "Claude 3.7 Sonnet (OR)", shortName: "CLAUDE 3.7", inputCostPerMillion: 3.00, isFree: false),
        LLMModelPricing(id: "meta-llama/llama-3.3-70b-instruct", providerKey: "openrouter", providerName: "OpenRouter", modelName: "Llama 3.3 70B (OR)", shortName: "LLAMA 70B", inputCostPerMillion: 0.40, isFree: false),
        LLMModelPricing(id: "qwen/qwen-2.5-72b-instruct", providerKey: "openrouter", providerName: "OpenRouter", modelName: "Qwen 2.5 72B (OR)", shortName: "QWEN 72B", inputCostPerMillion: 0.35, isFree: false),
        
        // Ollama Local
        LLMModelPricing(id: "llama3.3", providerKey: "ollama", providerName: "Ollama Local", modelName: "Llama 3.3", shortName: "LLAMA 3.3", inputCostPerMillion: 0.00, isFree: true),
        LLMModelPricing(id: "deepseek-r1-ollama", providerKey: "ollama", providerName: "Ollama Local", modelName: "DeepSeek R1 (Local)", shortName: "R1 LOCAL", inputCostPerMillion: 0.00, isFree: true),
        LLMModelPricing(id: "qwen2.5-coder", providerKey: "ollama", providerName: "Ollama Local", modelName: "Qwen 2.5 Coder", shortName: "QWEN CODER", inputCostPerMillion: 0.00, isFree: true),
        LLMModelPricing(id: "mistral", providerKey: "ollama", providerName: "Ollama Local", modelName: "Mistral Nemo", shortName: "MISTRAL", inputCostPerMillion: 0.00, isFree: true),
        LLMModelPricing(id: "phi4", providerKey: "ollama", providerName: "Ollama Local", modelName: "Phi-4", shortName: "PHI-4", inputCostPerMillion: 0.00, isFree: true)
    ]
}

@MainActor
class DevToolsManager: ObservableObject {
    static let shared = DevToolsManager()
    
    @Published var activePorts: [DevPortInfo] = [
        DevPortInfo(id: 3000, serviceName: "Next.js / React (3000)", isOpen: false),
        DevPortInfo(id: 5173, serviceName: "Vite / Svelte (5173)", isOpen: false),
        DevPortInfo(id: 8000, serviceName: "Python / FastAPI (8000)", isOpen: false),
        DevPortInfo(id: 8080, serviceName: "Backend / Spring (8080)", isOpen: false),
        DevPortInfo(id: 11434, serviceName: "Ollama Local (11434)", isOpen: false)
    ]
    
    @Published var tokenCalcText: String = ""
    @Published var tokenEstimateCount: Int = 0
    @Published var isFetchingModels: Bool = false
    @Published var dynamicModelsByProvider: [String: [LLMModelPricing]] = [:]
    
    private var scanTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadCachedDynamicModels()
        startPortScanning()
        
        // Listen to changes in LLMTrackerManager (e.g. user toggles a provider or enters API key)
        LLMTrackerManager.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        Task {
            await fetchLiveModels()
        }
    }
    
    // MARK: - Dynamic Active Providers from AI Quota
    var activeProviders: [DevToolsProvider] {
        let tracker = LLMTrackerManager.shared
        var list: [DevToolsProvider] = []
        
        // 1. Z.ai (GLM)
        if tracker.enableZai || !tracker.zaiApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "zai",
                name: "Z.ai (GLM)",
                shortName: "Z.AI",
                icon: "network",
                defaultModelId: "glm-4-plus"
            ))
        }
        
        // 2. Google Gemini
        if tracker.enableGemini || !tracker.geminiApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "gemini",
                name: "Google Gemini",
                shortName: "GEMINI",
                icon: "sparkles",
                defaultModelId: "gemini-2.0-flash"
            ))
        }
        
        // 3. DeepSeek
        if tracker.enableDeepSeek || !tracker.deepSeekApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "deepseek",
                name: "DeepSeek",
                shortName: "DEEPSEEK",
                icon: "brain.head.profile",
                defaultModelId: "deepseek-v3"
            ))
        }
        
        // 4. Anthropic Claude
        if tracker.enableClaude || !tracker.claudeSessionToken.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "claude",
                name: "Anthropic Claude",
                shortName: "CLAUDE",
                icon: "bubble.left.and.bubble.right.fill",
                defaultModelId: "claude-3-7-sonnet"
            ))
        }
        
        // 5. OpenAI / Codex
        if tracker.enableCodex || !tracker.codexApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "codex",
                name: "OpenAI",
                shortName: "OPENAI",
                icon: "chevron.left.forwardslash.chevron.right",
                defaultModelId: "gpt-4o-mini"
            ))
        }
        
        // 6. xAI Grok
        if tracker.enableGrok || !tracker.grokApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "grok",
                name: "xAI Grok",
                shortName: "GROK",
                icon: "bolt.fill",
                defaultModelId: "grok-2"
            ))
        }
        
        // 7. OpenRouter
        if tracker.enableOpenRouter || !tracker.openRouterApiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            list.append(DevToolsProvider(
                id: "openrouter",
                name: "OpenRouter",
                shortName: "OPENROUTER",
                icon: "arrow.triangle.branch",
                defaultModelId: "deepseek/deepseek-r1"
            ))
        }
        
        // 8. Ollama Local
        if tracker.enableOllama {
            list.append(DevToolsProvider(
                id: "ollama",
                name: "Ollama Local",
                shortName: "OLLAMA",
                icon: "desktopcomputer",
                defaultModelId: "llama3.3"
            ))
        }
        
        // 9. Custom Providers
        for cp in tracker.customProviders where cp.isEnabled {
            let pid = "custom_\(cp.id.uuidString)"
            list.append(DevToolsProvider(
                id: pid,
                name: cp.name,
                shortName: cp.name.uppercased(),
                icon: "slider.horizontal.3",
                defaultModelId: "\(pid)_default"
            ))
        }
        
        // Fallback default if absolutely nothing is enabled
        if list.isEmpty {
            list = [
                DevToolsProvider(id: "zai", name: "Z.ai (GLM)", shortName: "Z.AI", icon: "network", defaultModelId: "glm-4-plus"),
                DevToolsProvider(id: "gemini", name: "Google Gemini", shortName: "GEMINI", icon: "sparkles", defaultModelId: "gemini-2.0-flash")
            ]
        }
        
        return list
    }
    
    // MARK: - Models for a Specific Provider
    func models(for providerId: String) -> [LLMModelPricing] {
        var list: [LLMModelPricing] = []
        
        // 1. Built-in catalog models
        let catalogMatches = LLMModelPricing.catalog.filter { $0.providerKey == providerId }
        list.append(contentsOf: catalogMatches)
        
        // 2. Dynamic live models fetched from API
        if let dynamicList = dynamicModelsByProvider[providerId] {
            for dyn in dynamicList {
                if !list.contains(where: { $0.id == dyn.id }) {
                    list.append(dyn)
                }
            }
        }
        
        // 3. Custom provider support
        if providerId.hasPrefix("custom_") {
            let cpId = providerId.replacingOccurrences(of: "custom_", with: "")
            if let cp = LLMTrackerManager.shared.customProviders.first(where: { $0.id.uuidString == cpId }) {
                if list.isEmpty {
                    list = [
                        LLMModelPricing(
                            id: "\(providerId)_default",
                            providerKey: providerId,
                            providerName: cp.name,
                            modelName: cp.name,
                            shortName: String(cp.name.prefix(8)).uppercased(),
                            inputCostPerMillion: 1.00,
                            isFree: false
                        )
                    ]
                }
            }
        }
        
        return list
    }
    
    // MARK: - Selected Model per Provider (Persisted)
    func selectedModel(for providerId: String) -> LLMModelPricing {
        let providerModels = models(for: providerId)
        let savedKey = "devTools_selected_model_\(providerId)"
        if let savedId = UserDefaults.standard.string(forKey: savedKey),
           let found = providerModels.first(where: { $0.id == savedId }) {
            return found
        }
        return providerModels.first ?? LLMModelPricing.fallback(for: providerId)
    }
    
    func selectModel(id: String, for providerId: String) {
        let savedKey = "devTools_selected_model_\(providerId)"
        UserDefaults.standard.set(id, forKey: savedKey)
        objectWillChange.send()
    }
    
    func updateTokenEstimate(for text: String) {
        self.tokenCalcText = text
        let count = max(0, text.count / 4)
        self.tokenEstimateCount = count
    }
    
    // MARK: - Live API Model Fetching
    func fetchLiveModels() async {
        isFetchingModels = true
        let tracker = LLMTrackerManager.shared
        
        // 1. Z.ai (GLM)
        let zaiKey = tracker.zaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !zaiKey.isEmpty {
            await fetchOpenAICompatibleModels(
                providerKey: "zai",
                providerName: "Z.ai (GLM)",
                endpoint: "https://open.bigmodel.cn/api/paas/v4/models",
                apiKey: zaiKey
            )
        }
        
        // 2. Google Gemini
        let geminiKey = tracker.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !geminiKey.isEmpty {
            await fetchGeminiModels(key: geminiKey)
        }
        
        // 3. DeepSeek
        let dsKey = tracker.deepSeekApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dsKey.isEmpty {
            await fetchOpenAICompatibleModels(
                providerKey: "deepseek",
                providerName: "DeepSeek",
                endpoint: "https://api.deepseek.com/models",
                apiKey: dsKey
            )
        }
        
        // 4. OpenAI
        let codexKey = tracker.codexApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !codexKey.isEmpty {
            await fetchOpenAICompatibleModels(
                providerKey: "codex",
                providerName: "OpenAI",
                endpoint: "https://api.openai.com/v1/models",
                apiKey: codexKey
            )
        }
        
        // 5. OpenRouter (includes live model pricing per token)
        let orKey = tracker.openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !orKey.isEmpty {
            await fetchOpenRouterModels(key: orKey)
        }
        
        // 6. Ollama Local
        if tracker.enableOllama {
            await fetchOllamaModels(host: tracker.ollamaHost)
        }
        
        // 7. Custom Providers with /models support
        for cp in tracker.customProviders where cp.isEnabled && !cp.apiKey.isEmpty {
            let pid = "custom_\(cp.id.uuidString)"
            let cleanBase = cp.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            let modelsUrl = cleanBase.hasSuffix("/v1") ? "\(cleanBase)/models" : "\(cleanBase)/v1/models"
            await fetchOpenAICompatibleModels(
                providerKey: pid,
                providerName: cp.name,
                endpoint: modelsUrl,
                apiKey: cp.apiKey
            )
        }
        
        saveCachedDynamicModels()
        isFetchingModels = false
    }
    
    private func fetchOpenAICompatibleModels(providerKey: String, providerName: String, endpoint: String, apiKey: String) async {
        guard let url = URL(string: endpoint) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            
            struct ModelsResponse: Decodable {
                struct ModelItem: Decodable {
                    let id: String
                }
                let data: [ModelItem]
            }
            
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            var newModels: [LLMModelPricing] = []
            
            for item in decoded.data {
                let id = item.id
                // Filter out non-chat / internal embedding models
                if id.contains("embedding") || id.contains("moderation") || id.contains("tts") || id.contains("whisper") {
                    continue
                }
                
                // Determine price based on model heuristics if not in catalog
                let costPerMillion: Double
                let isFree: Bool
                
                if let known = LLMModelPricing.catalog.first(where: { $0.id.lowercased() == id.lowercased() || id.contains($0.id) }) {
                    costPerMillion = known.inputCostPerMillion
                    isFree = known.isFree
                } else if id.contains("flash") || id.contains("free") {
                    costPerMillion = 0.0
                    isFree = true
                } else if id.contains("air") || id.contains("mini") || id.contains("lite") {
                    costPerMillion = 0.15
                    isFree = false
                } else if id.contains("plus") || id.contains("pro") {
                    costPerMillion = 0.70
                    isFree = false
                } else {
                    costPerMillion = 0.50
                    isFree = false
                }
                
                let short = String(id.replacingOccurrences(of: "models/", with: "").prefix(12)).uppercased()
                newModels.append(LLMModelPricing(
                    id: id,
                    providerKey: providerKey,
                    providerName: providerName,
                    modelName: id,
                    shortName: short,
                    inputCostPerMillion: costPerMillion,
                    isFree: isFree
                ))
            }
            
            if !newModels.isEmpty {
                self.dynamicModelsByProvider[providerKey] = newModels
            }
        } catch {
            // Silently fail, built-in catalog provides 100% fallback
        }
    }
    
    private func fetchGeminiModels(key: String) async {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            
            struct GeminiResponse: Decodable {
                struct ModelItem: Decodable {
                    let name: String
                    let displayName: String?
                    let supportedGenerationMethods: [String]?
                }
                let models: [ModelItem]
            }
            
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            var newModels: [LLMModelPricing] = []
            
            for m in decoded.models {
                guard let methods = m.supportedGenerationMethods, methods.contains("generateContent") else { continue }
                let rawId = m.name.replacingOccurrences(of: "models/", with: "")
                let display = m.displayName ?? rawId
                
                var cost: Double = 0.10
                var isFree: Bool = true // Free tier in Google AI Studio
                
                if rawId.contains("pro") && !rawId.contains("exp") {
                    cost = 1.25
                    isFree = false
                } else if rawId.contains("flash-8b") {
                    cost = 0.0375
                    isFree = false
                }
                
                let short = String(rawId.replacingOccurrences(of: "gemini-", with: "").prefix(10)).uppercased()
                newModels.append(LLMModelPricing(
                    id: rawId,
                    providerKey: "gemini",
                    providerName: "Google Gemini",
                    modelName: display,
                    shortName: short,
                    inputCostPerMillion: cost,
                    isFree: isFree
                ))
            }
            
            if !newModels.isEmpty {
                self.dynamicModelsByProvider["gemini"] = newModels
            }
        } catch {}
    }
    
    private func fetchOpenRouterModels(key: String) async {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 8
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            
            struct ORResponse: Decodable {
                struct ORModel: Decodable {
                    let id: String
                    let name: String?
                    struct Pricing: Decodable {
                        let prompt: String?
                    }
                    let pricing: Pricing?
                }
                let data: [ORModel]
            }
            
            let decoded = try JSONDecoder().decode(ORResponse.self, from: data)
            var newModels: [LLMModelPricing] = []
            
            for m in decoded.data {
                let costPerToken = Double(m.pricing?.prompt ?? "0") ?? 0.0
                let costPerMillion = costPerToken * 1_000_000.0
                let isFree = costPerMillion == 0
                
                let short = String(m.id.components(separatedBy: "/").last ?? m.id).prefix(10).uppercased()
                newModels.append(LLMModelPricing(
                    id: m.id,
                    providerKey: "openrouter",
                    providerName: "OpenRouter",
                    modelName: m.name ?? m.id,
                    shortName: short,
                    inputCostPerMillion: costPerMillion,
                    isFree: isFree
                ))
            }
            
            if !newModels.isEmpty {
                self.dynamicModelsByProvider["openrouter"] = newModels
            }
        } catch {}
    }
    
    private func fetchOllamaModels(host: String) async {
        let clean = host.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(clean)/api/tags") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            
            struct OllamaResponse: Decodable {
                struct TagItem: Decodable {
                    let name: String
                }
                let models: [TagItem]
            }
            
            let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
            var newModels: [LLMModelPricing] = []
            
            for m in decoded.models {
                let cleanName = m.name.replacingOccurrences(of: ":latest", with: "")
                newModels.append(LLMModelPricing(
                    id: "ollama-\(m.name)",
                    providerKey: "ollama",
                    providerName: "Ollama Local",
                    modelName: cleanName,
                    shortName: String(cleanName.prefix(10)).uppercased(),
                    inputCostPerMillion: 0.0,
                    isFree: true
                ))
            }
            
            if !newModels.isEmpty {
                self.dynamicModelsByProvider["ollama"] = newModels
            }
        } catch {}
    }
    
    // MARK: - Dynamic Model Cache
    private func saveCachedDynamicModels() {
        if let encoded = try? JSONEncoder().encode(dynamicModelsByProvider) {
            UserDefaults.standard.set(encoded, forKey: "devTools_cached_dynamic_models")
        }
    }
    
    private func loadCachedDynamicModels() {
        if let data = UserDefaults.standard.data(forKey: "devTools_cached_dynamic_models"),
           let decoded = try? JSONDecoder().decode([String: [LLMModelPricing]].self, from: data) {
            self.dynamicModelsByProvider = decoded
        }
    }
    
    // MARK: - Port Scanning
    func startPortScanning() {
        scanTimer?.invalidate()
        scanPorts()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanPorts()
            }
        }
    }
    
    func scanPorts() {
        for (index, portInfo) in activePorts.enumerated() {
            checkPort(port: portInfo.id) { [weak self] isOpen in
                Task { @MainActor [weak self] in
                    guard let self = self, index < self.activePorts.count else { return }
                    self.activePorts[index].isOpen = isOpen
                }
            }
        }
    }
    
    private func checkPort(port: Int, completion: @escaping @Sendable (Bool) -> Void) {
        let host = NWEndpoint.Host("127.0.0.1")
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(false)
            return
        }
        
        let connection = NWConnection(host: host, port: nwPort, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.cancel()
                completion(true)
            case .failed, .cancelled:
                completion(false)
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            if connection.state != .ready {
                connection.cancel()
                completion(false)
            }
        }
    }
}
