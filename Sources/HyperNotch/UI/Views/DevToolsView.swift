import SwiftUI
import AppKit

struct DevToolsView: View {
    @ObservedObject var devTools = DevToolsManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Left: Active Dev Ports
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        Text(loc("LOCALHOST SERVERS", "ЛОКАЛЬНЫЕ СЕРВЕРЫ"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        devTools.scanPorts()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(loc("Refresh ports", "Обновить порты"))
                }
                
                VStack(spacing: 5) {
                    ForEach(devTools.activePorts) { port in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(port.isOpen ? Color.green : Color.white.opacity(0.2))
                                .frame(width: 6, height: 6)
                                .shadow(color: port.isOpen ? Color.green.opacity(0.6) : Color.clear, radius: 3)
                            
                            Text(port.serviceName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(port.isOpen ? .white : .secondary)
                            
                            Spacer()
                            
                            if port.isOpen {
                                Button(loc("Open", "Открыть")) {
                                    if let url = URL(string: "http://localhost:\(port.id)") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                
                Spacer()
            }
            .frame(width: 235)
            .padding(10)
            .heroGlassCard(cornerRadius: 13)
            
            // Right: Instant Token & Cost Calculator
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 3)
                    
                    Text(loc("TOKEN & COST CALCULATOR", "КАЛЬКУЛЯТОР ТОКЕНОВ И СТОИМОСТИ"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Paste from clipboard button
                    Button(action: {
                        if let pasteText = NSPasteboard.general.string(forType: .string) {
                            devTools.tokenCalcText = pasteText
                            devTools.updateTokenEstimate(for: pasteText)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.clipboard")
                            Text(loc("Paste", "Вставить"))
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    
                    // Clear button
                    if !devTools.tokenCalcText.isEmpty {
                        Button(action: {
                            devTools.tokenCalcText = ""
                            devTools.updateTokenEstimate(for: "")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                TextField(loc("Paste text or prompt to estimate tokens...", "Вставьте текст или промпт для оценки токенов..."), text: $devTools.tokenCalcText, axis: .vertical)
                    .lineLimit(2...3)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(6)
                    .heroInputBox(cornerRadius: 7)
                    .onChange(of: devTools.tokenCalcText) { _, newText in
                        devTools.updateTokenEstimate(for: newText)
                    }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("EST. TOKENS", "ТОКЕНЫ (~TOK)"))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("\(devTools.tokenEstimateCount)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 26)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CLAUDE 3.7")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "$%.5f", devTools.sonnetCostEstimate))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 26)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GPT-4O")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "$%.5f", devTools.gpt4oCostEstimate))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 26)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("CHARS", "СИМВОЛЫ"))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("\(devTools.tokenCalcText.count)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.top, 4)
                
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .heroGlassCard(cornerRadius: 13)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
