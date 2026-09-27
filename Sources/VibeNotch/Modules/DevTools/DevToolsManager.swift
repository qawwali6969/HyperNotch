import SwiftUI
import Foundation
import Network

struct DevPortInfo: Identifiable, Equatable {
    let id: Int // Port number
    let serviceName: String
    var isOpen: Bool
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
    
    private var scanTimer: Timer?
    
    init() {
        startPortScanning()
    }
    
    // Singleton lives for app lifecycle
    
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
