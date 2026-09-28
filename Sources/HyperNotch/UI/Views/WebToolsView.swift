import SwiftUI
import AppKit

// MARK: - Curated Vibe-Coder & AI Creator Icon Categories
struct VibeIconCategory: Identifiable {
    var id: String { nameEn }
    let nameEn: String
    let nameRu: String
    let icon: String
    let icons: [String]
    
    @MainActor
    var name: String {
        loc(nameEn, nameRu)
    }
}

struct WebToolsView: View {
    @ObservedObject var manager = WebToolsManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showingAddSheet = false
    @State private var hoveredItemId: UUID? = nil
    @State private var isAddHovered = false
    
    // Add Link Form State (White is default!)
    @State private var newTitle = ""
    @State private var newUrl = ""
    @State private var selectedIcon = "sparkles"
    @State private var selectedColor = "white"
    @State private var selectedCategoryIndex = 0
    @State private var useFavicon = false
    @State private var previewFaviconData: Data? = nil
    @State private var isLoadingFavicon = false
    
    // Curated Golden Icon Set for Vibe-Coders & AI Creators
    let categories: [VibeIconCategory] = [
        VibeIconCategory(
            nameEn: "AI & Models",
            nameRu: "AI & Нейросети",
            icon: "sparkles",
            icons: [
                "sparkles",                     // Magic / Prompts
                "brain.head.profile",           // LLM / Claude / GPT
                "wand.and.stars",               // AI Video & Image Gen
                "atom",                         // Deep Learning / Models
                "eye.fill",                     // Vision AI
                "waveform.badge.magnifyingglass", // Audio AI / ElevenLabs
                "bubble.left.and.bubble.right.fill", // Chat / Assistant
                "circle.hexagongrid.fill"       // Neural Weights
            ]
        ),
        VibeIconCategory(
            nameEn: "Vibe-Coding & Dev",
            nameRu: "Вайб-кодинг & Dev",
            icon: "terminal.fill",
            icons: [
                "terminal.fill",                // CLI / agy / Terminal
                "chevron.left.forwardslash.chevron.right", // Code / React / Next.js
                "curlybraces",                  // JSON / Schema / API
                "cpu.fill",                     // GPU / Compute / Hardware
                "server.rack",                  // Cloud / Backend / VPS
                "externaldrive.fill",           // Database / Supabase / Postgres
                "arrow.triangle.branch",        // Git / GitHub / Commits
                "shippingbox.fill"              // Packages / NPM / Build
            ]
        ),
        VibeIconCategory(
            nameEn: "Creative & Media",
            nameRu: "Креатив & Медиа",
            icon: "film.fill",
            icons: [
                "film.fill",                    // Video / Seedance / Runway
                "play.rectangle.fill",          // YouTube / Render
                "paintbrush.fill",              // Design / UI / Figma
                "music.note",                   // Audio / Suno / Sound
                "camera.fill",                  // Photo / Dribbble
                "cube.transparent",             // 3D / Spline / Blender
                "photo.stack.fill",             // Assets / Gallery
                "sparkle.magnifyingglass"       // Research / Prompts Library
            ]
        ),
        VibeIconCategory(
            nameEn: "Growth & Metrics",
            nameRu: "Рост & Метрики",
            icon: "flame.fill",
            icons: [
                "flame.fill",                   // Hype / Trends / Viral
                "dollarsign.circle.fill",       // Stripe / MRR / Revenue
                "chart.line.uptrend.xyaxis",   // Growth / Analytics
                "bolt.fill",                    // Realtime / Speed
                "megaphone.fill",               // Launch / ProductHunt
                "globe",                        // Live Domain / Web
                "creditcard.fill",              // Subscriptions / Billing
                "star.fill"                     // Favorites / Pinned
            ]
        )
    ]
    
    // White is the FIRST and DEFAULT color: white, blue, red, yellow, orange, green, purple, pink
    let availableColors = ["white", "blue", "red", "yellow", "orange", "green", "purple", "pink"]
    
    var body: some View {
        VStack(spacing: 8) {
            // V2 Module Header
            V2ModuleHeader(
                tab: .webTools,
                statusText: "\(manager.items.count) \(loc("SERVICES", "СЕРВИСА")) · БРАУЗЕР НА КАЖДЫЙ"
            ) {
                // Target Browser Pill
                Menu {
                    ForEach(TargetBrowser.allCases) { browser in
                        Button(action: {
                            manager.selectedBrowser = browser
                        }) {
                            HStack {
                                Text(browser.rawValue)
                                if manager.selectedBrowser == browser {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                            .font(.system(size: 9))
                        Text(manager.selectedBrowser.rawValue)
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(V2Colors.dim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
                
                // Open Mode (Tab vs Window)
                Picker("", selection: $manager.openMode) {
                    ForEach(OpenTargetMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 120)
                .scaleEffect(0.8)
                
                V2GlassButton(
                    title: showingAddSheet ? loc("Close", "Закрыть") : loc("Add", "Добавить"),
                    icon: showingAddSheet ? "xmark" : "plus"
                ) {
                    withAnimation(.spring) {
                        showingAddSheet.toggle()
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            if showingAddSheet {
                addLinkForm
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                VStack(spacing: 10) {
                    dockBar
                    tooltipBar
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Compact, Perfectly Balanced Add Form (V2 Engineering HUD)
    private var addFormPreviewIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    themeManager.currentTheme == .engineeringV2
                        ? LinearGradient(colors: [V2Colors.ice.opacity(0.24), V2Colors.ice.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(white: 0.22), Color(white: 0.10)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(
                            themeManager.currentTheme == .engineeringV2 ? V2Colors.ice2.opacity(0.7) : Color.white.opacity(0.25),
                            lineWidth: 1.2
                        )
                )
                .overlay(
                    Group {
                        if useFavicon, let data = previewFaviconData, let nsImg = NSImage(data: data) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .shadow(color: .white.opacity(0.5), radius: 4)
                        } else if useFavicon && isLoadingFavicon {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(colorFromName(selectedColor))
                                .shadow(color: colorFromName(selectedColor).opacity(0.6), radius: 4)
                        }
                    }
                )
                .shadow(
                    color: themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.35) : colorFromName(selectedColor).opacity(0.25),
                    radius: 6,
                    y: 2
                )
        }
    }
    
    private var addFormTextFields: some View {
        HStack(spacing: 6) {
            TextField(loc("Title (Claude / Midjourney)", "Название (Claude / Midjourney)"), text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeManager.currentTheme == .engineeringV2 ? V2Colors.edge : Color.white.opacity(0.12), lineWidth: 1))
                )
            
            TextField(loc("URL (https://...)", "URL (https://...)"), text: $newUrl)
                .textFieldStyle(.plain)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeManager.currentTheme == .engineeringV2 ? V2Colors.edge : Color.white.opacity(0.12), lineWidth: 1))
                )
                .onChange(of: newUrl) { _, newVal in
                    autoDetectIconAndColor(for: newVal)
                    if useFavicon && !newVal.isEmpty {
                        fetchPreviewFavicon(for: newVal)
                    }
                }
        }
    }
    
    private var addFormCategoriesAndToggle: some View {
        HStack(spacing: 4) {
            ForEach(categories.indices, id: \.self) { idx in
                let cat = categories[idx]
                let isSelected = selectedCategoryIndex == idx
                Button(action: {
                    withAnimation(.spring(response: 0.2)) {
                        selectedCategoryIndex = idx
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 8))
                        Text(cat.name)
                            .font(.system(size: 8.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isSelected ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.22) : Color.white.opacity(0.2)) : Color.white.opacity(0.04))
                            .overlay(
                                Capsule().stroke(
                                    isSelected ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice2.opacity(0.6) : Color.white) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.edge : Color.white.opacity(0.1)),
                                    lineWidth: 1
                                )
                            )
                    )
                    .foregroundStyle(isSelected ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.secondary))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Toggle(isOn: $useFavicon) {
                HStack(spacing: 3) {
                    Image(systemName: "globe")
                        .font(.system(size: 8.5))
                    Text(loc("Use favicon", "Использовать favicon"))
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(useFavicon ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.secondary))
            }
            .toggleStyle(.checkbox)
            .onChange(of: useFavicon) { _, enabled in
                if enabled && !newUrl.isEmpty {
                    fetchPreviewFavicon(for: newUrl)
                }
            }
        }
    }
    
    private var addFormIconSelector: some View {
        let activeCategory = categories[selectedCategoryIndex]
        return HStack(spacing: 5) {
            ForEach(activeCategory.icons, id: \.self) { icon in
                let isSelected = selectedIcon == icon
                Button(action: {
                    selectedIcon = icon
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isSelected
                                    ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.24) : Color.white.opacity(0.2))
                                    : Color.white.opacity(0.04)
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        isSelected
                                            ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice2.opacity(0.7) : Color.white)
                                            : (themeManager.currentTheme == .engineeringV2 ? V2Colors.edge : Color.white.opacity(0.1)),
                                        lineWidth: 1
                                    )
                            )
                        
                        Image(systemName: icon)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
                                    : (themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.secondary)
                            )
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(isSelected ? 1.08 : 1.0)
            }
        }
    }
    
    private var addFormColorSwatches: some View {
        HStack(spacing: 4) {
            ForEach(availableColors, id: \.self) { color in
                let isSelected = selectedColor == color
                Button(action: { selectedColor = color }) {
                    Circle()
                        .fill(colorFromName(color))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                        )
                        .shadow(color: colorFromName(color).opacity(isSelected ? 0.7 : 0.0), radius: 3)
                }
                .buttonStyle(.plain)
                .scaleEffect(isSelected ? 1.2 : 1.0)
            }
        }
    }
    
    private var addFormActionButtons: some View {
        HStack(spacing: 6) {
            V2GlassButton(title: loc("Cancel", "Отмена")) {
                withAnimation(.spring) {
                    showingAddSheet = false
                    useFavicon = false
                    previewFaviconData = nil
                }
            }
            
            V2GlassButton(title: loc("Add", "Добавить"), icon: "plus", isKey: true) {
                let titleToSave = newTitle.isEmpty ? cleanHost(newUrl) : newTitle
                manager.addItem(
                    title: titleToSave,
                    url: newUrl,
                    iconName: selectedIcon,
                    colorName: selectedColor,
                    useCustomFavicon: useFavicon
                )
                newTitle = ""
                newUrl = ""
                useFavicon = false
                previewFaviconData = nil
                withAnimation(.spring) {
                    showingAddSheet = false
                }
            }
        }
    }

    private var addLinkForm: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                addFormPreviewIcon
                
                VStack(spacing: 5) {
                    addFormTextFields
                    addFormCategoriesAndToggle
                }
            }
            
            HStack(spacing: 6) {
                addFormIconSelector
                
                Spacer()
                
                addFormColorSwatches
                
                addFormActionButtons
            }
        }
        .padding(10)
        .heroGlassCard(cornerRadius: 13)
        .padding(.horizontal, 16)
    }
    
    private func fetchPreviewFavicon(for urlString: String) {
        isLoadingFavicon = true
        Task {
            let data = await manager.fetchFavicon(for: urlString)
            await MainActor.run {
                self.previewFaviconData = data
                self.isLoadingFavicon = false
            }
        }
    }
    
    // MARK: - Auto-detect Icon from URL
    private func autoDetectIconAndColor(for urlString: String) {
        let low = urlString.lowercased()
        if low.contains("claude") || low.contains("anthropic") {
            selectedIcon = "brain.head.profile"
            selectedColor = "white"
            selectedCategoryIndex = 0
            if newTitle.isEmpty { newTitle = "Claude AI" }
        } else if low.contains("chatgpt") || low.contains("openai") {
            selectedIcon = "sparkles"
            selectedColor = "white"
            selectedCategoryIndex = 0
            if newTitle.isEmpty { newTitle = "ChatGPT" }
        } else if low.contains("midjourney") || low.contains("dreamina") || low.contains("seedance") || low.contains("kling") {
            selectedIcon = "wand.and.stars"
            selectedColor = "white"
            selectedCategoryIndex = 0
            if newTitle.isEmpty { newTitle = "AI Generator" }
        } else if low.contains("github") || low.contains("gitlab") {
            selectedIcon = "arrow.triangle.branch"
            selectedColor = "white"
            selectedCategoryIndex = 1
            if newTitle.isEmpty { newTitle = "GitHub" }
        } else if low.contains("figma") || low.contains("dribbble") || low.contains("21st") {
            selectedIcon = "paintbrush.fill"
            selectedColor = "white"
            selectedCategoryIndex = 2
            if newTitle.isEmpty { newTitle = "Design" }
        } else if low.contains("youtube") {
            selectedIcon = "play.rectangle.fill"
            selectedColor = "white"
            selectedCategoryIndex = 2
            if newTitle.isEmpty { newTitle = "YouTube" }
        } else if low.contains("stripe") {
            selectedIcon = "dollarsign.circle.fill"
            selectedColor = "white"
            selectedCategoryIndex = 3
            if newTitle.isEmpty { newTitle = "Stripe" }
        } else if low.contains("suno") || low.contains("elevenlabs") {
            selectedIcon = "waveform.badge.magnifyingglass"
            selectedColor = "white"
            selectedCategoryIndex = 0
            if newTitle.isEmpty { newTitle = "Audio AI" }
        }
    }
    
    // MARK: - The Hero Dock Bar
    private var dockBar: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ForEach(manager.items) { item in
                            DockItemButton(
                                item: item,
                                isHovered: hoveredItemId == item.id,
                                onHover: { hovering in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        hoveredItemId = hovering ? item.id : (hoveredItemId == item.id ? nil : hoveredItemId)
                                    }
                                },
                                onDelete: {
                                    manager.removeItem(id: item.id)
                                },
                                onTap: {
                                    manager.open(item: item)
                                }
                            )
                        }
                        
                        Rectangle()
                            .fill(themeManager.currentTheme == .engineeringV2 ? V2Colors.line : Color.white.opacity(0.12))
                            .frame(width: 1, height: 26)
                            .padding(.horizontal, 2)
                        
                        dockAddButton
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(dockPillBackground)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 90)
    }
    
    private var dockPillBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(
                themeManager.currentTheme == .engineeringV2
                    ? AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.065), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.black.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(
                    themeManager.currentTheme == .engineeringV2 ? V2Colors.edge : Color.white.opacity(0.12),
                    lineWidth: 1
                )
            )
            .shadow(color: (themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.black).opacity(0.55), radius: 16, y: 6)
    }
    
    private var dockAddFill: Color {
        if themeManager.currentTheme == .engineeringV2 {
            return isAddHovered ? V2Colors.ice.opacity(0.18) : Color.white.opacity(0.035)
        } else {
            return isAddHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08)
        }
    }
    
    private var dockAddStroke: Color {
        if themeManager.currentTheme == .engineeringV2 {
            return isAddHovered ? V2Colors.ice2.opacity(0.7) : V2Colors.edge
        } else {
            return isAddHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.12)
        }
    }
    
    private var dockAddForeground: Color {
        if themeManager.currentTheme == .engineeringV2 {
            return isAddHovered ? V2Colors.ice1 : V2Colors.faint
        } else {
            return isAddHovered ? Color.white : Color.secondary
        }
    }

    private var dockAddButton: some View {
        Button(action: {
            withAnimation(.spring) {
                showingAddSheet.toggle()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(dockAddFill)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(dockAddStroke, lineWidth: 1)
                    )
                
                Image(systemName: showingAddSheet ? "xmark" : "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(dockAddForeground)
            }
            .scaleEffect(isAddHovered ? 1.08 : 1.0)
            .offset(y: isAddHovered ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isAddHovered = $0 }
        .help(loc("Add web app to dock", "Добавить веб-сервис в док"))
    }
    
    private var tooltipDefaultText: some View {
        let browserName = manager.selectedBrowser.rawValue.uppercased()
        let txt = loc("CLICK ICON TO OPEN IN \(browserName)", "КЛИКНИТЕ ДЛЯ ОТКРЫТИЯ В \(browserName)")
        let fgColor = themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.secondary
        return Text(txt)
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(fgColor)
    }
    
    @ViewBuilder
    private func tooltipHoveredText(for item: WebToolItem) -> some View {
        let titleColor = themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white
        let hostColor = themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.secondary
        let capsuleBg = themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.12) : Color.white.opacity(0.08)
        let capsuleStroke = themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.25) : Color.white.opacity(0.12)
        
        HStack(spacing: 5) {
            Text(item.title.uppercased())
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundStyle(titleColor)
            
            Text("·")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(V2Colors.faint)
            
            Text(cleanHost(item.url))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(hostColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(capsuleBg)
                .overlay(Capsule().stroke(capsuleStroke, lineWidth: 1))
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var tooltipBar: some View {
        Group {
            if let id = hoveredItemId, let hovered = manager.items.first(where: { $0.id == id }) {
                tooltipHoveredText(for: hovered)
            } else {
                tooltipDefaultText
            }
        }
    }
    
    private func colorFromName(_ name: String) -> Color {
        switch name.lowercased() {
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
    
    private func cleanHost(_ urlStr: String) -> String {
        guard let url = URL(string: urlStr) else { return urlStr }
        return url.host ?? urlStr
    }
}

// MARK: - HeroDock Icon Button
struct DockItemButton: View {
    let item: WebToolItem
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    
    @ObservedObject var themeManager = ThemeManager.shared
    
    private var bgFill: AnyShapeStyle {
        if themeManager.currentTheme == .engineeringV2 {
            if isHovered {
                return AnyShapeStyle(LinearGradient(colors: [V2Colors.ice.opacity(0.22), V2Colors.ice.opacity(0.08)], startPoint: .top, endPoint: .bottom))
            } else {
                return AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.065), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            }
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(white: 0.16).opacity(isHovered ? 0.95 : 0.75),
                    Color(white: 0.08).opacity(isHovered ? 0.95 : 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
    
    private var strokeColor: Color {
        if themeManager.currentTheme == .engineeringV2 {
            return isHovered ? V2Colors.ice2.opacity(0.7) : V2Colors.edge
        } else {
            return isHovered ? Color.white.opacity(0.45) : Color.white.opacity(0.15)
        }
    }
    
    private var iconForeground: Color {
        if themeManager.currentTheme == .engineeringV2 {
            if item.colorName == "white" || item.displayColor == .white {
                return isHovered ? V2Colors.milk : V2Colors.dim
            } else {
                return item.displayColor
            }
        } else {
            return item.colorName == "white" || item.displayColor == .white ? Color.white : item.displayColor
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(bgFill)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(strokeColor, lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if item.useCustomFavicon, let data = item.faviconImageData, let nsImg = NSImage(data: data) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .shadow(color: .white.opacity(isHovered ? 0.6 : 0.2), radius: isHovered ? 6 : 2, y: 1)
                            } else {
                                Image(systemName: item.iconName)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(iconForeground)
                                    .shadow(color: (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice : iconForeground).opacity(isHovered ? 0.5 : 0.1), radius: isHovered ? 6 : 1, y: 1)
                            }
                        }
                    )
                    .shadow(
                        color: themeManager.currentTheme == .engineeringV2
                            ? V2Colors.ice.opacity(isHovered ? 0.35 : 0.0)
                            : (item.useCustomFavicon ? Color.white : iconForeground).opacity(isHovered ? 0.35 : 0.05),
                        radius: isHovered ? 10 : 2,
                        y: isHovered ? 3 : 1
                    )
                
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : .white.opacity(0.9))
                            .background(Circle().fill(themeManager.currentTheme == .engineeringV2 ? Color(hex: "0B0E12") : Color.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2, y: -2)
                }
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
            .offset(y: isHovered ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { onHover($0) }
    }
}
