import SwiftUI

enum AIPresetType: String, CaseIterable, Identifiable {
    case gemini = "Gemini"
    case claude = "Claude"
    case codex = "Codex / OpenAI"
    case grok = "Grok (xAI)"
    case zai = "Z.ai (GLM)"
    case openRouter = "OpenRouter"
    case deepSeek = "DeepSeek"
    case ollama = "Ollama"
    case custom = "+ Кастомный / Jev"
    
    var id: String { rawValue }
    
    @MainActor
    var localizedTitle: String {
        switch self {
        case .custom: return loc("+ Custom / Jev", "+ Кастомный / Jev")
        default: return rawValue
        }
    }
    
    var icon: String {
        switch self {
        case .gemini: return "sparkles"
        case .claude: return "bubble.left.and.bubble.right.fill"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .grok: return "bolt.fill"
        case .zai: return "network"
        case .openRouter: return "arrow.triangle.branch"
        case .deepSeek: return "brain.head.profile"
        case .ollama: return "desktopcomputer"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct AIQuotaView: View {
    @ObservedObject var tracker = LLMTrackerManager.shared
    @ObservedObject var coordinator = NotchStateCoordinator.shared
    @ObservedObject var localization = LocalizationManager.shared
    @State private var isManaging = false
    
    var body: some View {
        VStack(spacing: 8) {
            // V2 Module Header
            V2ModuleHeader(
                tab: .aiQuota,
                statusText: "\(tracker.activeQuotas.count) \(loc("PROVIDERS", "ПРОВАЙДЕРА")) · СБРОС СКОРО"
            ) {
                V2GlassButton(
                    title: isManaging ? loc("Done", "Готово") : loc("Add", "Добавить"),
                    icon: isManaging ? "checkmark" : "plus",
                    isKey: isManaging
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isManaging.toggle()
                    }
                    if !isManaging {
                        Task {
                            await tracker.refreshAll()
                        }
                    }
                }
                
                Button(action: {
                    Task {
                        await tracker.refreshAll()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9.5))
                        .rotationEffect(.degrees(tracker.isRefreshing ? 360 : 0))
                        .animation(tracker.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: tracker.isRefreshing)
                        .foregroundStyle(V2Colors.dim)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Content
            if isManaging {
                AIProviderManagerView(onDone: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isManaging = false
                    }
                })
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                if tracker.activeQuotas.isEmpty {
                    emptyStateView
                } else {
                    quotaListView
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.3), radius: 6)
            
            Text(loc("No AI providers connected", "Нет подключенных нейросетей"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
            
            Text(loc("Connect Gemini, Claude, Codex, Grok, Z.ai or custom proxy endpoints", "Подключите Gemini, Claude, Codex, Grok, Z.ai или кастомный провайдер (Jev, прокси)"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            VibeInteractiveHoverButton(
                text: loc("Add AI Provider", "Добавить нейросеть"),
                leadingIcon: "plus",
                icon: "arrow.right",
                fontSize: 10,
                horizontalPadding: 12,
                verticalPadding: 5,
                minHeight: 26
            ) {
                withAnimation(.spring) {
                    isManaging = true
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }
    
    private var quotaListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tracker.activeQuotas) { quota in
                    QuotaCard(quota: quota)
                }
                
                // Add More Card
                Button(action: {
                    withAnimation(.spring) {
                        isManaging = true
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(loc("Add", "Добавить"))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(width: 80, height: 142)
                    .heroGlassCard(cornerRadius: 13)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - In-Tab AI Provider Manager (Add / Configure Models directly here)
struct AIProviderManagerView: View {
    @ObservedObject var tracker = LLMTrackerManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    var onDone: () -> Void
    
    @State private var selectedTab: AIPresetType = .gemini
    @State private var savedNotice = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Preset Selection Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AIPresetType.allCases) { preset in
                        let isSelected = selectedTab == preset
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = preset
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 8.5))
                                Text(preset.localizedTitle)
                                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                            )
                            .overlay(
                                Capsule().stroke(isSelected ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Detail Configuration Card for Selected Preset
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    switch selectedTab {
                    case .gemini:
                        Toggle("Включить Google Gemini", isOn: $tracker.enableGemini)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Google AI Studio API Key (AIzaSy...):")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("AIzaSy...", text: $tracker.geminiApiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        Text("Автоматически отслеживает дневную квоту Google AI Studio и сброс по вашему часовому поясу.")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                    case .claude:
                        Toggle("Включить Claude", isOn: $tracker.enableClaude)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Сессионный токен (опционально, если не используется Claude Code CLI):")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("sessionKey...", text: $tracker.claudeSessionToken)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        Text("Если запущен 'claude' CLI, лимит 5-часового окна подхватывается автоматически из кэша.")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                    case .codex:
                        Toggle("Включить Codex / OpenAI", isOn: $tracker.enableCodex)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("OpenAI API Key (sk-...):")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("sk-...", text: $tracker.codexApiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        
                    case .grok:
                        Toggle("Включить Grok (xAI)", isOn: $tracker.enableGrok)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("xAI API Key (xai-...):")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("xai-...", text: $tracker.grokApiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        
                    case .zai:
                        Toggle("Включить Z.ai (Zhipu / GLM)", isOn: $tracker.enableZai)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Z.ai API Key:")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("API Key...", text: $tracker.zaiApiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        
                    case .openRouter:
                        Toggle("Включить OpenRouter", isOn: $tracker.enableOpenRouter)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("OpenRouter API Key (sk-or-v1-...):")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("sk-or-v1-...", text: $tracker.openRouterApiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        
                    case .deepSeek:
                        Toggle("Включить DeepSeek", isOn: $tracker.enableDeepSeek)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("DeepSeek API Key (sk-...):")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            SecureField("sk-...", text: $tracker.deepSeekApiKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        
                    case .ollama:
                        Toggle("Включить Ollama Local", isOn: $tracker.enableOllama)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ollama Host URL:")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                            TextField("http://127.0.0.1:11434", text: $tracker.ollamaHost)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(5)
                                .heroInputBox(cornerRadius: 6)
                        }
                        
                    case .custom:
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Кастомные провайдеры (Jev, прокси, Mistral и др.):")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    tracker.addCustomProvider()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "plus")
                                        Text("Добавить")
                                    }
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if tracker.customProviders.isEmpty {
                                Text("Нажмите «Добавить», чтобы настроить любой OpenAI-совместимый эндпоинт.")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach($tracker.customProviders) { $item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Toggle("", isOn: $item.isEnabled)
                                                .toggleStyle(.checkbox)
                                                .labelsHidden()
                                            
                                            TextField("Название (например, Jev)", text: $item.name)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(.white)
                                                .padding(3)
                                                .heroInputBox(cornerRadius: 5)
                                                .frame(width: 120)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                tracker.removeCustomProvider(id: item.id)
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 8.5))
                                                    .foregroundStyle(.red.opacity(0.8))
                                                    .padding(3)
                                                    .background(Color.red.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        HStack(spacing: 6) {
                                            TextField("Base URL (e.g. https://api.z.ai/v1)", text: $item.baseUrl)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.white)
                                                .padding(3)
                                                .heroInputBox(cornerRadius: 5)
                                            
                                            SecureField("API Key", text: $item.apiKey)
                                                .textFieldStyle(.plain)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.white)
                                                .padding(3)
                                                .heroInputBox(cornerRadius: 5)
                                        }
                                    }
                                    .padding(6)
                                    .background(Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                    }
                    
                    // Action Buttons Row
                    HStack {
                        VibeInteractiveHoverButton(
                            text: savedNotice ? "Сохранено!" : "Подключить и обновить",
                            leadingIcon: savedNotice ? "checkmark" : "arrow.triangle.2.circlepath",
                            icon: "arrow.right",
                            fontSize: 9.5,
                            horizontalPadding: 10,
                            verticalPadding: 4,
                            minHeight: 24
                        ) {
                            Task {
                                await tracker.refreshAll()
                                savedNotice = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    savedNotice = false
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 12)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Quota Window Row
struct QuotaWindowRow: View {
    let window: LLMQuotaWindow
    
    private var isCrit: Bool { window.effectiveRemaining <= 15 }
    private var isWarn: Bool { window.effectiveRemaining > 15 && window.effectiveRemaining <= 35 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(V2Colors.dim)
                
                Spacer()
                
                Text(window.usageText)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isCrit ? V2Colors.red : (isWarn ? V2Colors.amber : V2Colors.ice1))
            }
            
            V2Gauge(
                progress: window.effectiveRemaining / 100.0,
                isWarning: isWarn,
                isCritical: isCrit
            )
            
            if let resetDesc = window.resetDescription {
                Text(resetDesc.uppercased())
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(V2Colors.faint)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Quota Card
struct QuotaCard: View {
    let quota: LLMQuotaInfo
    @ObservedObject var tracker = LLMTrackerManager.shared
    
    private var isAlarmSet: Bool {
        tracker.alarmSetItemId == quota.id
    }
    
    private var targetResetDate: Date {
        let candidateDates = quota.windows.compactMap { $0.resetDate }.filter { $0 > Date() }
        if let earliest = candidateDates.min() {
            return earliest
        }
        if let qDate = quota.resetDate, qDate > Date() {
            return qDate
        }
        if let qDate = quota.resetDate {
            var advanced = qDate
            while advanced <= Date() {
                advanced = advanced.addingTimeInterval(3600 * 5)
            }
            return advanced
        }
        return Date().addingTimeInterval(3600 * 3)
    }
    
    private var alarmTimeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: targetResetDate)
    }
    
    private var statusChip: (String, V2ChipStyle) {
        if quota.isError {
            return ("Ошибка", .crit)
        }
        if let lowest = quota.windows.map({ $0.effectiveRemaining }).min() {
            if lowest <= 15 { return ("Предел", .crit) }
            if lowest <= 35 { return ("Внимание", .warn) }
        }
        return ("Норма", .ice)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Card Header
            HStack(spacing: 5) {
                Text(quota.providerName)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(V2Colors.milk)
                
                Text(quota.planName)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(V2Colors.dim)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                
                Spacer(minLength: 4)
                
                V2Chip(statusChip.0, style: statusChip.1)
            }
            
            if quota.isError {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(V2Colors.red)
                        Text(quota.resetTimeDescription)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(V2Colors.red)
                    }
                    Text(quota.detailText)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(V2Colors.faint)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(V2Colors.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if !quota.windows.isEmpty {
                VStack(spacing: 4) {
                    ForEach(quota.windows) { window in
                        QuotaWindowRow(window: window)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9))
                            .foregroundStyle(V2Colors.ice1)
                        Text(quota.resetTimeDescription)
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(V2Colors.milk)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Spacer(minLength: 0)
            
            // Card Footer
            HStack {
                Text("КЛЮЧ · KEYCHAIN")
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(V2Colors.faint)
                
                Spacer()
                
                if !quota.isError {
                    V2GlassButton(
                        title: isAlarmSet ? "Стоит · \(alarmTimeString)" : "Будильник \(alarmTimeString)",
                        icon: isAlarmSet ? "checkmark" : "alarm.fill",
                        isKey: isAlarmSet
                    ) {
                        tracker.setAlarmForReset(quota: quota, targetResetDate: targetResetDate)
                    }
                }
            }
        }
        .padding(9)
        .frame(width: 215, height: 168)
        .heroGlassCard(cornerRadius: 13)
    }
}

