import SwiftUI
import Foundation
import Network

struct DevPortInfo: Identifiable, Equatable {
    let id: Int // Port number
    let serviceName: String
    var isOpen: Bool
}

struct LLMModelPricing: Identifiable, Equatable {
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
    
    static let catalog: [LLMModelPricing] = [
        // Google Gemini
        LLMModelPricing(id: "gemini-2-0-flash", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 2.0 Flash", shortName: "GEMINI FLASH", inputCostPerMillion: 0.10, isFree: true),
        LLMModelPricing(id: "gemini-2-0-pro", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 2.0 Pro", shortName: "GEMINI PRO", inputCostPerMillion: 1.25, isFree: false),
        LLMModelPricing(id: "gemini-1-5-flash", providerKey: "gemini", providerName: "Google Gemini", modelName: "Gemini 1.5 Flash", shortName: "GEMINI 1.5 F", inputCostPerMillion: 0.075, isFree: false),
        
        // DeepSeek
        LLMModelPricing(id: "deepseek-v3", providerKey: "deepseek", providerName: "DeepSeek", modelName: "DeepSeek V3", shortName: "DEEPSEEK V3", inputCostPerMillion: 0.14, isFree: false),
        LLMModelPricing(id: "deepseek-r1", providerKey: "deepseek", providerName: "DeepSeek", modelName: "DeepSeek R1", shortName: "DEEPSEEK R1", inputCostPerMillion: 0.55, isFree: false),
        
        // Anthropic Claude
        LLMModelPricing(id: "claude-3-7-sonnet", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.7 Sonnet", shortName: "CLAUDE 3.7", inputCostPerMillion: 3.00, isFree: false),
        LLMModelPricing(id: "claude-3-5-sonnet", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.5 Sonnet", shortName: "CLAUDE 3.5", inputCostPerMillion: 3.00, isFree: false),
        LLMModelPricing(id: "claude-3-5-haiku", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3.5 Haiku", shortName: "CLAUDE HAIKU", inputCostPerMillion: 0.80, isFree: false),
        LLMModelPricing(id: "claude-3-opus", providerKey: "claude", providerName: "Anthropic Claude", modelName: "Claude 3 Opus", shortName: "CLAUDE OPUS", inputCostPerMillion: 15.00, isFree: false),
        
        // OpenAI
        LLMModelPricing(id: "gpt-4o", providerKey: "codex", providerName: "OpenAI", modelName: "GPT-4o", shortName: "GPT-4O", inputCostPerMillion: 2.50, isFree: false),
        LLMModelPricing(id: "gpt-4o-mini", providerKey: "codex", providerName: "OpenAI", modelName: "GPT-4o mini", shortName: "GPT-4O MINI", inputCostPerMillion: 0.15, isFree: false),
        LLMModelPricing(id: "o3-mini", providerKey: "codex", providerName: "OpenAI", modelName: "o3-mini", shortName: "O3-MINI", inputCostPerMillion: 1.10, isFree: false),
        LLMModelPricing(id: "o1", providerKey: "codex", providerName: "OpenAI", modelName: "o1", shortName: "O1", inputCostPerMillion: 15.00, isFree: false),
        
        // xAI Grok
        LLMModelPricing(id: "grok-2", providerKey: "grok", providerName: "xAI Grok", modelName: "Grok 2", shortName: "GROK 2", inputCostPerMillion: 2.00, isFree: false),
        LLMModelPricing(id: "grok-2-mini", providerKey: "grok", providerName: "xAI Grok", modelName: "Grok 2 mini", shortName: "GROK MINI", inputCostPerMillion: 0.20, isFree: false),
        
        // Z.ai GLM
        LLMModelPricing(id: "glm-4-plus", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 Plus", shortName: "GLM-4 PLUS", inputCostPerMillion: 0.50, isFree: false),
        LLMModelPricing(id: "glm-4-flash", providerKey: "zai", providerName: "Z.ai (GLM)", modelName: "GLM-4 Flash", shortName: "GLM-4 FLASH", inputCostPerMillion: 0.01, isFree: true),
        
        // Ollama Local
        LLMModelPricing(id: "ollama-local", providerKey: "ollama", providerName: "Ollama Local", modelName: "Ollama Local Models", shortName: "OLLAMA", inputCostPerMillion: 0.00, isFree: true)
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
    
    // Model Selection (persisted)
    @Published var selectedModelAId: String = UserDefaults.standard.string(forKey: "devTools_modelA_id") ?? "deepseek-v3" {
        didSet { UserDefaults.standard.set(selectedModelAId, forKey: "devTools_modelA_id") }
    }
    @Published var selectedModelBId: String = UserDefaults.standard.string(forKey: "devTools_modelB_id") ?? "claude-3-7-sonnet" {
        didSet { UserDefaults.standard.set(selectedModelBId, forKey: "devTools_modelB_id") }
    }
    
    var allAvailableModels: [LLMModelPricing] {
        var list = LLMModelPricing.catalog
        for cp in LLMTrackerManager.shared.customProviders where cp.isEnabled {
            list.append(LLMModelPricing(
                id: "custom-\(cp.id)",
                providerKey: "custom",
                providerName: cp.name,
                modelName: cp.name,
                shortName: cp.name.uppercased(),
                inputCostPerMillion: 1.00,
                isFree: false
            ))
        }
        return list
    }
    
    var activeModelsFromQuotas: [LLMModelPricing] {
        let tracker = LLMTrackerManager.shared
        return allAvailableModels.filter { model in
            switch model.providerKey {
            case "gemini": return tracker.enableGemini || !tracker.geminiApiKey.isEmpty
            case "deepseek": return tracker.enableDeepSeek || !tracker.deepSeekApiKey.isEmpty
            case "claude": return tracker.enableClaude || !tracker.claudeSessionToken.isEmpty
            case "codex": return tracker.enableCodex || !tracker.codexApiKey.isEmpty
            case "grok": return tracker.enableGrok || !tracker.grokApiKey.isEmpty
            case "zai": return tracker.enableZai || !tracker.zaiApiKey.isEmpty
            case "ollama": return tracker.enableOllama
            case "custom": return true
            default: return false
            }
        }
    }
    
    var selectedModelA: LLMModelPricing {
        allAvailableModels.first(where: { $0.id == selectedModelAId }) ?? (allAvailableModels.first(where: { $0.id == "deepseek-v3" }) ?? allAvailableModels[0])
    }
    
    var selectedModelB: LLMModelPricing {
        allAvailableModels.first(where: { $0.id == selectedModelBId }) ?? (allAvailableModels.first(where: { $0.id == "claude-3-7-sonnet" }) ?? allAvailableModels[0])
    }
    
    private var scanTimer: Timer?
    
    init() {
        startPortScanning()
    }
    
    func updateTokenEstimate(for text: String) {
        self.tokenCalcText = text
        let count = max(0, text.count / 4)
        self.tokenEstimateCount = count
    }
    
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
        
        // Timeout after 400ms
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            if connection.state != .ready {
                connection.cancel()
                completion(false)
            }
        }
    }
}
