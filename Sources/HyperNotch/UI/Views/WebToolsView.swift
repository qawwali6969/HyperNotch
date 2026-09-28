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
    
    // MARK: - Compact, Perfectly Balanced Add Form (Fits notch perfectly!)
    private var addLinkForm: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                // 1. Live Preview of Dock Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.22),
                                    Color(white: 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
                        )
                        .overlay(
                            Group {
                                if useFavicon, let data = previewFaviconData, let nsImg = NSImage(data: data) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        .shadow(color: (useFavicon ? Color.white : colorFromName(selectedColor)).opacity(0.25), radius: 6, y: 2)
                }
                
                // 2. Input Fields
                VStack(spacing: 5) {
                    HStack(spacing: 6) {
                        TextField(loc("Title (Claude / Midjourney)", "Название (Claude / Midjourney)"), text: $newTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        TextField(loc("URL (https://...)", "URL (https://...)"), text: $newUrl)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onChange(of: newUrl) { oldVal, newVal in
                                autoDetectIconAndColor(for: newVal)
                                if useFavicon && !newVal.isEmpty {
                                    fetchPreviewFavicon(for: newVal)
                                }
                            }
                    }
                    
                    // 3. Category Selector Pills & Favicon Checkbox
                    HStack(spacing: 4) {
                        ForEach(categories.indices, id: \.self) { idx in
                            let cat = categories[idx]
                            Button(action: {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedCategoryIndex = idx
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 8))
                                    Text(cat.name)
                                        .font(.system(size: 9, weight: selectedCategoryIndex == idx ? .bold : .medium))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(selectedCategoryIndex == idx ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                .foregroundStyle(selectedCategoryIndex == idx ? .white : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        // "Use favicon" Checkbox
                        Toggle(isOn: $useFavicon) {
                            HStack(spacing: 3) {
                                Image(systemName: "globe")
                                    .font(.system(size: 9))
                                Text(loc("Use favicon", "Использовать favicon"))
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(useFavicon ? .white : .secondary)
                        }
                        .toggleStyle(.checkbox)
                        .onChange(of: useFavicon) { _, enabled in
                            if enabled && !newUrl.isEmpty {
                                fetchPreviewFavicon(for: newUrl)
                            }
                        }
                    }
                }
            }
            
            // 4. Icon Selector (28x28px) + Color Swatches + Submit
            let activeCategory = categories[selectedCategoryIndex]
            HStack(spacing: 6) {
                // Icons row
                ForEach(activeCategory.icons, id: \.self) { icon in
                    let isSelected = selectedIcon == icon
                    Button(action: {
                        selectedIcon = icon
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
                                )
                            
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                }
                
                Spacer()
                
                // Color Swatches (White is first!)
                HStack(spacing: 4) {
                    ForEach(availableColors, id: \.self) { color in
                        let isSelected = selectedColor == color
                        Button(action: { selectedColor = color }) {
                            Circle()
                                .fill(colorFromName(color))
                                .frame(width: 14, height: 14)
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
                
                // Cancel & Save Buttons
                HStack(spacing: 5) {
                    Button(loc("Cancel", "Отмена")) {
                        withAnimation(.spring) {
                            showingAddSheet = false
                            useFavicon = false
                            previewFaviconData = nil
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    
                    VibeInteractiveHoverButton(text: loc("Add", "Добавить"), icon: "plus", fontSize: 9, horizontalPadding: 9, verticalPadding: 4, minHeight: 24) {
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
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
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
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 1, height: 26)
                            .padding(.horizontal, 2)
                        
                        dockAddButton
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 90)
    }
    
    private var dockAddButton: some View {
        Button(action: {
            withAnimation(.spring) {
                showingAddSheet.toggle()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isAddHovered ? 0.18 : 0.08), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(Color.white.opacity(isAddHovered ? 0.35 : 0.12), lineWidth: 1)
                    )
                
                Image(systemName: showingAddSheet ? "xmark" : "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isAddHovered ? .white : .secondary)
            }
            .scaleEffect(isAddHovered ? 1.08 : 1.0)
            .offset(y: isAddHovered ? -3 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isAddHovered = $0 }
        .help(loc("Add web app to dock", "Добавить веб-сервис в док"))
    }
    
    private var tooltipBar: some View {
        Group {
            if let id = hoveredItemId, let hovered = manager.items.first(where: { $0.id == id }) {
                HStack(spacing: 5) {
                    Text(hovered.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    
                    Text(cleanHost(hovered.url))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text(loc("Click icon to open in \(manager.selectedBrowser.rawValue)", "Кликните на иконку, чтобы открыть в \(manager.selectedBrowser.rawValue)"))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
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
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.16).opacity(isHovered ? 0.95 : 0.75),
                                Color(white: 0.08).opacity(isHovered ? 0.95 : 0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.45 : 0.15),
                                        Color.white.opacity(isHovered ? 0.2 : 0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
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
                                    .foregroundStyle(item.colorName == "white" || item.displayColor == .white ? Color.white : item.displayColor)
                                    .shadow(color: (item.colorName == "white" || item.displayColor == .white ? Color.white : item.displayColor).opacity(isHovered ? 0.7 : 0.2), radius: isHovered ? 6 : 2, y: 1)
                            }
                        }
                    )
                    .shadow(color: (item.useCustomFavicon ? Color.white : (item.colorName == "white" || item.displayColor == .white ? Color.white : item.displayColor)).opacity(isHovered ? 0.35 : 0.05), radius: isHovered ? 10 : 2, y: isHovered ? 3 : 1)
                
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.9))
                            .background(Circle().fill(.black.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2, y: -2)
                }
            }
            .scaleEffect(isHovered ? 1.09 : 1.0)
            .offset(y: isHovered ? -3 : 0)
        }
        .buttonStyle(.plain)
        .onHover { onHover($0) }
    }
}
