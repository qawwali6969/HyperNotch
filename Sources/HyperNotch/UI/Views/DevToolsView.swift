import SwiftUI
import AppKit

struct DevToolsView: View {
    @ObservedObject var devTools = DevToolsManager.shared
    @ObservedObject var tracker = LLMTrackerManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // V2 Module Header
            V2ModuleHeader(
                tab: .devTools,
                statusText: "\(devTools.activePorts.filter { $0.isOpen }.count) \(loc("RUNNING", "ЗАПУЩЕНО")) · 2 \(loc("IDLE", "СВОБОДНО"))"
            ) {
                V2GlassButton(
                    title: loc("Scan", "Сканировать"),
                    icon: "arrow.triangle.2.circlepath"
                ) {
                    devTools.scanPorts()
                }
            }
            
            // Duo Body Panels (Matching Prototype .duo)
            HStack(spacing: 11) {
                // Left: Active Dev Ports
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(loc("LOCALHOST PORTS", "ПОРТЫ LOCALHOST"))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(V2Colors.faint)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 5) {
                        ForEach(devTools.activePorts) { port in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(port.isOpen ? V2Colors.ice : V2Colors.faint.opacity(0.4))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: port.isOpen ? V2Colors.ice.opacity(0.7) : Color.clear, radius: 3)
                                
                                Text("\(port.id)")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(port.isOpen ? V2Colors.milk : V2Colors.faint)
                                    .frame(width: 44, alignment: .leading)
                                
                                Text(port.serviceName)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(port.isOpen ? V2Colors.dim : V2Colors.faint)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if port.isOpen {
                                    Button(action: {
                                        if let url = URL(string: "http://localhost:\(port.id)") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Text(loc("Open", "Открыть"))
                                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(V2Colors.ice.opacity(0.14))
                                            .foregroundStyle(V2Colors.ice1)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 250)
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
                
                // Right: Instant Token & Cost Calculator with Dynamic Provider Slots
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(loc("TOKENS & COST", "ТОКЕНЫ И СТОИМОСТЬ"))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(V2Colors.faint)
                        
                        // Live API Refresh Icon
                        Button(action: {
                            Task {
                                await devTools.fetchLiveModels()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(V2Colors.faint)
                                .rotationEffect(.degrees(devTools.isFetchingModels ? 360 : 0))
                                .animation(devTools.isFetchingModels ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: devTools.isFetchingModels)
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)
                        .help(loc("Refresh models from active APIs", "Обновить список моделей по API"))
                        
                        Spacer()
                        
                        // Paste button
                        Button(action: {
                            if let paste = NSPasteboard.general.string(forType: .string) {
                                devTools.tokenCalcText = paste
                                devTools.updateTokenEstimate(for: paste)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                Text(loc("Paste", "Вставить"))
                            }
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(V2Colors.ice1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(V2Colors.ice.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        
                        // Clear button
                        if !devTools.tokenCalcText.isEmpty {
                            Button(action: {
                                devTools.tokenCalcText = ""
                                devTools.updateTokenEstimate(for: "")
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(V2Colors.faint)
                                    .padding(3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    TextField(loc("Paste text or prompt to estimate tokens...", "Вставьте текст или промпт для оценки токенов..."), text: $devTools.tokenCalcText, axis: .vertical)
                        .lineLimit(2...3)
                        .textFieldStyle(.plain)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(V2Colors.milk)
                        .padding(6)
                        .heroInputBox(cornerRadius: 7)
                        .onChange(of: devTools.tokenCalcText) { _, newText in
                            devTools.updateTokenEstimate(for: newText)
                        }
                    
                    // Dynamic Provider Cost Row: 1 provider = 1 price, 2 providers = 2 prices, etc.
                    HStack(spacing: 10) {
                        // Tokens count
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("TOKENS", "ТОКЕНЫ"))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.faint)
                            
                            Text("\(devTools.tokenEstimateCount)")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.livingIceHGradient)
                        }
                        
                        // Dynamic slots for each active provider configured in AI Quota
                        if devTools.activeProviders.isEmpty {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1, height: 26)
                            
                            Text(loc("Enable providers in AI Quota", "Включите API в Квотах"))
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(V2Colors.dim)
                        } else {
                            ForEach(devTools.activeProviders) { provider in
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 1, height: 26)
                                
                                ProviderCostColumn(
                                    provider: provider,
                                    tokens: devTools.tokenEstimateCount
                                )
                            }
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1, height: 26)
                        
                        // Chars count
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("CHARS", "СИМВОЛЫ"))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.faint)
                            
                            Text("\(devTools.tokenCalcText.count)")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.dim)
                        }
                        
                        Spacer(minLength: 0)
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
}

struct ProviderCostColumn: View {
    let provider: DevToolsProvider
    let tokens: Int
    @ObservedObject var devTools = DevToolsManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    
    var selectedModel: LLMModelPricing {
        devTools.selectedModel(for: provider.id)
    }
    
    var providerModels: [LLMModelPricing] {
        devTools.models(for: provider.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Dropdown menu showing ONLY this provider's models
            Menu {
                Section("\(provider.name) — \(loc("Models", "Модели"))") {
                    ForEach(providerModels) { model in
                        Button(action: {
                            devTools.selectModel(id: model.id, for: provider.id)
                        }) {
                            HStack {
                                Text(model.displayNameWithPrice)
                                if selectedModel.id == model.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3.5) {
                    Image(systemName: provider.icon)
                        .font(.system(size: 7.5))
                        .foregroundStyle(V2Colors.ice1)
                    
                    Text("\(provider.shortName): \(selectedModel.shortName)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(V2Colors.faint)
                }
                .foregroundStyle(V2Colors.milk)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(V2Colors.ice.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(V2Colors.ice.opacity(0.25), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            
            // Computed cost for this specific provider model
            Text(selectedModel.formattedCost(tokens: tokens))
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(selectedModel.isFree ? V2Colors.ice1 : V2Colors.amber)
                .lineLimit(1)
        }
    }
}
