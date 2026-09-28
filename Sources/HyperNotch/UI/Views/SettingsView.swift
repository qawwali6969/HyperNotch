import SwiftUI

struct SettingsView: View {
    @ObservedObject var clipboard = ClipboardManager.shared
    @ObservedObject var webTools = WebToolsManager.shared
    @ObservedObject var coordinator = NotchStateCoordinator.shared
    @ObservedObject var quickAI = QuickAIEngine.shared
    @ObservedObject var llmTracker = LLMTrackerManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var updater = UpdateManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var clearedNotification = false
    
    // API Key entry states
    @State private var newGeminiKey: String = ""
    @State private var newZaiKey: String = ""
    @State private var isEditingGemini = false
    @State private var isEditingZai = false
    
    var body: some View {
        VStack(spacing: 8) {
            // V2 Module Header
            V2ModuleHeader(
                tab: .settings,
                statusText: loc("LOCAL ONLY · NO TELEMETRY", "ЛОКАЛЬНО · ТЕЛЕМЕТРИИ НЕТ")
            )
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    // Section 0: Design Theme (Default: V2 Engineering HUD, Switchable to V1 Classic)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                            .shadow(color: (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white).opacity(0.4), radius: 3)
                        
                        Text(loc("DESIGN THEME", "ТЕМА ОФОРМЛЕНИЯ"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
                        
                        Spacer()
                        
                        Text(loc("Default: V2 Engineering", "По умолчанию: V2 Инженерный"))
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        ForEach(AppTheme.allCases) { theme in
                            let isSelected = themeManager.currentTheme == theme
                            Button(action: {
                                themeManager.setTheme(theme)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: theme.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(
                                            isSelected
                                                ? (theme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                                                : Color.secondary
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            Text(theme.displayName)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundStyle(isSelected ? (theme == .engineeringV2 ? V2Colors.milk : Color.white) : Color.secondary)
                                            
                                            if theme == .engineeringV2 {
                                                Text("DEFAULT")
                                                    .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1.5)
                                                    .background(Capsule().fill(V2Colors.ice1.opacity(0.2)))
                                                    .foregroundStyle(V2Colors.ice1)
                                            }
                                        }
                                        
                                        Text(theme.subtitle)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(theme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isSelected
                                                ? (theme == .engineeringV2 ? V2Colors.ice.opacity(0.12) : Color.white.opacity(0.12))
                                                : Color.white.opacity(0.04)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isSelected
                                                ? (theme == .engineeringV2 ? V2Colors.ice2.opacity(0.6) : Color.white.opacity(0.4))
                                                : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
                
                // Section 1: Language Selection (Default: English, Switchable to Russian)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        Text(loc("INTERFACE LANGUAGE", "ЯЗЫК ИНТЕРФЕЙСА"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(loc("Applied instantly", "Применяется мгновенно"))
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        Text(loc("Select Language:", "Выберите язык:"))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: Binding(
                            get: { localization.currentLanguage },
                            set: { localization.setLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text("\(lang.flag) \(lang.displayName)").tag(lang)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
                
                // Section 2: Web Tools Browser Preferences
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        Text(loc("WEB TOOLS & BROWSER", "ВЕБ-ИНСТРУМЕНТЫ & БРАУЗЕР"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc("Default Browser:", "Браузер по умолчанию:"))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: $webTools.selectedBrowser) {
                                ForEach(TargetBrowser.allCases) { browser in
                                    Text(browser.rawValue).tag(browser)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 170)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc("Open Mode:", "Режим открытия:"))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: $webTools.openMode) {
                                ForEach(OpenTargetMode.allCases) { mode in
                                    Text(mode.localizedTitle).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                    }
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
                
                // Section 3: Quick AI Engine & API Provider Settings
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cyan)
                            .shadow(color: Color.cyan.opacity(0.4), radius: 3)
                        
                        Text(loc("QUICK AI & API PROVIDERS", "AI-ОТВЕТЫ И ВЫБОР ПРОВАЙДЕРА"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text(quickAI.selectedProvider.localizedSubtitle)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Provider selector
                    HStack(spacing: 12) {
                        Text(loc("Provider for quick responses:", "Провайдер для быстрых ответов:"))
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: $quickAI.selectedProvider) {
                            ForEach(QuickAIProvider.allCases) { provider in
                                Text(provider.localizedName).tag(provider)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // API Key Configurations
                    HStack(spacing: 12) {
                        // Gemini Key Block
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Google Gemini API:")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                if !llmTracker.geminiApiKey.isEmpty {
                                    Text(loc("✓ Configured", "✓ Настроен"))
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.green)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                SecureField(llmTracker.geminiApiKey.isEmpty ? loc("Paste AIzaSy...", "Вставьте AIzaSy...") : "••••••••••••••••", text: $newGeminiKey)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                
                                Button(loc("Save", "Сохранить")) {
                                    let clean = newGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !clean.isEmpty {
                                        llmTracker.geminiApiKey = clean
                                        newGeminiKey = ""
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.2))
                                .foregroundStyle(Color.cyan)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                        
                        // Z.ai Key Block
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Z.ai (BigModel) API:")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                if !llmTracker.zaiApiKey.isEmpty {
                                    Text(loc("✓ Configured", "✓ Настроен"))
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.green)
                                }
                            }
                            
                            HStack(spacing: 4) {
                                SecureField(llmTracker.zaiApiKey.isEmpty ? loc("Paste id.secret...", "Вставьте id.secret...") : "••••••••••••••••", text: $newZaiKey)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                
                                Button(loc("Save", "Сохранить")) {
                                    let clean = newZaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !clean.isEmpty {
                                        llmTracker.zaiApiKey = clean
                                        newZaiKey = ""
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundStyle(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                    }
                    
                    // Token explanation footnote
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.secondary)
                        Text(loc(
                            "Usage: ~100–300 tokens per answer. Gemini 2.0 Flash is free (15 RPM / 1M tokens/day). All keys are encrypted in Apple Keychain.",
                            "Расход: ~100–300 токенов на ответ. Gemini 2.0 Flash бесплатен (15 RPM / 1M токенов/день). Все ключи хранятся в зашифрованном Apple Keychain."
                        ))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
                
                // Section 4: Data Management & Buffer Maintenance
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        Text(loc("DATA MANAGEMENT", "УПРАВЛЕНИЕ ДАННЫМИ"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    HStack(spacing: 10) {
                        VibeInteractiveHoverButton(
                            text: loc("View AI Quotas", "Перейти к квотам AI"),
                            leadingIcon: "sparkles",
                            icon: "arrow.right",
                            fontSize: 9.5,
                            horizontalPadding: 10,
                            verticalPadding: 5,
                            minHeight: 24
                        ) {
                            coordinator.selectedTab = .aiQuota
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            clipboard.clearAll()
                            clearedNotification = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                clearedNotification = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: clearedNotification ? "checkmark" : "trash")
                                Text(clearedNotification ? loc("Clipboard cleared!", "Буфер очищен!") : loc("Clear clipboard history", "Очистить историю буфера"))
                            }
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(clearedNotification ? Color.green : Color.red.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(clearedNotification ? Color.green.opacity(0.15) : Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Section 5: Software Updates & Version
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.4), radius: 3)
                        
                        Text(loc("SOFTWARE UPDATES", "ОБНОВЛЕНИЯ ПРОГРАММЫ"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("v\(updater.currentVersion)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    if updater.updateAvailable {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.yellow)
                                Text(loc("New version \(updater.latestVersion) is available!", "Доступна новая версия \(updater.latestVersion)!"))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                if updater.isDownloading {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text(loc("Installing...", "Установка..."))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Button(action: {
                                        Task {
                                            await updater.installUpdate()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.circle.fill")
                                            Text(loc("Update & Relaunch", "Обновить и перезапустить"))
                                        }
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            if !updater.releaseNotes.isEmpty {
                                Text(updater.releaseNotes.prefix(200) + (updater.releaseNotes.count > 200 ? "..." : ""))
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        HStack(spacing: 10) {
                            VibeInteractiveHoverButton(
                                text: updater.isChecking ? loc("Checking...", "Проверка...") : loc("Check for Updates", "Проверить обновления"),
                                leadingIcon: updater.isChecking ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                                icon: "",
                                fontSize: 9.5,
                                horizontalPadding: 10,
                                verticalPadding: 5,
                                minHeight: 24
                            ) {
                                Task {
                                    await updater.checkForUpdates(silent: false)
                                }
                            }
                            
                            if let msg = updater.statusMessage {
                                Text(msg)
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(updater.isUpToDate ? Color.green : Color.secondary)
                            }
                            
                            if let err = updater.errorMessage {
                                Text(err)
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(Color.red.opacity(0.85))
                            }
                        }
                    }
                }
                .padding(10)
                .heroGlassCard(cornerRadius: 13)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}
}

