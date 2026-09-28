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
                
                // Right: Instant Token & Cost Calculator
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(loc("TOKENS & COST", "ТОКЕНЫ И СТОИМОСТЬ"))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(V2Colors.faint)
                        
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
                    
                    HStack(spacing: 11) {
                        // Tokens count
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("TOKENS", "ТОКЕНЫ"))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.faint)
                            
                            Text("\(devTools.tokenEstimateCount)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.livingIceHGradient)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1, height: 26)
                        
                        // Slot A: Model A Dropdown + Cost
                        VStack(alignment: .leading, spacing: 3) {
                            ModelDropdownMenu(
                                selectedId: $devTools.selectedModelAId,
                                activeModels: devTools.activeModelsFromQuotas,
                                allModels: devTools.allAvailableModels
                            )
                            
                            Text(devTools.selectedModelA.formattedCost(tokens: devTools.tokenEstimateCount))
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(devTools.selectedModelA.isFree ? V2Colors.ice1 : V2Colors.amber)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1, height: 26)
                        
                        // Slot B: Model B Dropdown + Cost
                        VStack(alignment: .leading, spacing: 3) {
                            ModelDropdownMenu(
                                selectedId: $devTools.selectedModelBId,
                                activeModels: devTools.activeModelsFromQuotas,
                                allModels: devTools.allAvailableModels
                            )
                            
                            Text(devTools.selectedModelB.formattedCost(tokens: devTools.tokenEstimateCount))
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(devTools.selectedModelB.isFree ? V2Colors.ice1 : V2Colors.amber)
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
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(V2Colors.dim)
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
}

struct ModelDropdownMenu: View {
    @Binding var selectedId: String
    let activeModels: [LLMModelPricing]
    let allModels: [LLMModelPricing]
    @ObservedObject var localization = LocalizationManager.shared
    
    var currentModel: LLMModelPricing {
        allModels.first(where: { $0.id == selectedId }) ?? (allModels.first ?? LLMModelPricing.catalog[0])
    }
    
    var body: some View {
        Menu {
            if !activeModels.isEmpty {
                Section(loc("★ Configured in AI Quota", "★ Активные в Квотах")) {
                    ForEach(activeModels) { model in
                        Button(action: { selectedId = model.id }) {
                            HStack {
                                Text(model.displayNameWithPrice)
                                if selectedId == model.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            
            Section("DeepSeek") {
                ForEach(allModels.filter { $0.providerKey == "deepseek" }) { model in
                    Button(action: { selectedId = model.id }) {
                        Text(model.displayNameWithPrice)
                    }
                }
            }
            
            Section("Anthropic Claude") {
                ForEach(allModels.filter { $0.providerKey == "claude" }) { model in
                    Button(action: { selectedId = model.id }) {
                        Text(model.displayNameWithPrice)
                    }
                }
            }
            
            Section("OpenAI") {
                ForEach(allModels.filter { $0.providerKey == "codex" }) { model in
                    Button(action: { selectedId = model.id }) {
                        Text(model.displayNameWithPrice)
                    }
                }
            }
            
            Section("Google Gemini") {
                ForEach(allModels.filter { $0.providerKey == "gemini" }) { model in
                    Button(action: { selectedId = model.id }) {
                        Text(model.displayNameWithPrice)
                    }
                }
            }
            
            Section("xAI Grok & Z.ai") {
                ForEach(allModels.filter { $0.providerKey == "grok" || $0.providerKey == "zai" }) { model in
                    Button(action: { selectedId = model.id }) {
                        Text(model.displayNameWithPrice)
                    }
                }
            }
            
            Section("Ollama & Custom") {
                ForEach(allModels.filter { $0.providerKey == "ollama" || $0.providerKey == "custom" }) { model in
                    Button(action: { selectedId = model.id }) {
                        Text(model.displayNameWithPrice)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentModel.shortName)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 6.5, weight: .bold))
            }
            .foregroundStyle(V2Colors.milk)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(V2Colors.ice.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(V2Colors.ice.opacity(0.25), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }
}
