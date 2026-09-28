import SwiftUI
import Foundation
import Network

struct DevPortInfo: Identifiable, Equatable {
    let id: Int // Port number
    let serviceName: String
    var isOpen: Bool
}

struct ProviderTokenCost: Identifiable, Equatable {
    let id: String
    let name: String
    let inputCostPerMillion: Double
    let isFree: Bool
    
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
    @Published var sonnetCostEstimate: Double = 0.0 // $3 / million input
    @Published var gpt4oCostEstimate: Double = 0.0   // $2.5 / million input
    
    var activeModelCosts: [ProviderTokenCost] {
        let tracker = LLMTrackerManager.shared
        var models: [ProviderTokenCost] = []
        
        if tracker.enableGemini || !tracker.geminiApiKey.isEmpty {
            models.append(ProviderTokenCost(id: "gemini", name: "GEMINI 2.0", inputCostPerMillion: 0.10, isFree: true))
        }
        if tracker.enableDeepSeek || !tracker.deepSeekApiKey.isEmpty {
            models.append(ProviderTokenCost(id: "deepseek", name: "DEEPSEEK V3", inputCostPerMillion: 0.14, isFree: false))
        }
        if tracker.enableClaude || !tracker.claudeSessionToken.isEmpty {
            models.append(ProviderTokenCost(id: "claude", name: "CLAUDE 3.7", inputCostPerMillion: 3.00, isFree: false))
        }
        if tracker.enableCodex || !tracker.codexApiKey.isEmpty {
            models.append(ProviderTokenCost(id: "codex", name: "GPT-4O", inputCostPerMillion: 2.50, isFree: false))
        }
        if tracker.enableGrok || !tracker.grokApiKey.isEmpty {
            models.append(ProviderTokenCost(id: "grok", name: "GROK 2", inputCostPerMillion: 2.00, isFree: false))
        }
        if tracker.enableZai || !tracker.zaiApiKey.isEmpty {
            models.append(ProviderTokenCost(id: "zai", name: "GLM-4 (Z.AI)", inputCostPerMillion: 0.50, isFree: false))
        }
        if tracker.enableOllama {
            models.append(ProviderTokenCost(id: "ollama", name: "OLLAMA", inputCostPerMillion: 0.00, isFree: true))
        }
        for p in tracker.customProviders where p.isEnabled {
            models.append(ProviderTokenCost(id: p.id.uuidString, name: p.name.uppercased(), inputCostPerMillion: 1.00, isFree: false))
        }
        
        if models.isEmpty {
            // Default benchmarks if no keys/providers are configured yet
            models.append(ProviderTokenCost(id: "gemini", name: "GEMINI 2.0", inputCostPerMillion: 0.10, isFree: true))
            models.append(ProviderTokenCost(id: "claude", name: "CLAUDE 3.7", inputCostPerMillion: 3.00, isFree: false))
            models.append(ProviderTokenCost(id: "codex", name: "GPT-4O", inputCostPerMillion: 2.50, isFree: false))
        }
        
        return models
    }
    
    private var scanTimer: Timer?
    
    init() {
        startPortScanning()
    }
    
    func updateTokenEstimate(for text: String) {
        self.tokenCalcText = text
        let count = max(0, text.count / 4)
        self.tokenEstimateCount = count
        // Sonnet 3.7: $3.00 per 1M input tokens
        self.sonnetCostEstimate = (Double(count) / 1_000_000.0) * 3.00
        // GPT-4o: $2.50 per 1M input tokens
        self.gpt4oCostEstimate = (Double(count) / 1_000_000.0) * 2.50
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
