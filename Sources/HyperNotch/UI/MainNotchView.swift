import SwiftUI
import AppKit

@MainActor
class NotchStateCoordinator: ObservableObject {
    static let shared = NotchStateCoordinator()
    
    @Published var isExpanded: Bool = false
    @Published var isPinned: Bool = false
    @Published var selectedTab: NotchTab = .shelf
    @Published var notchSize: CGSize = CGSize(width: 190, height: 34)
    
    var openSize: CGSize {
        let totalHeight = notchSize.height + 250
        return CGSize(width: 800, height: totalHeight)
    }
    
    var currentClosedSize: CGSize {
        var extraWidth: CGFloat = 0
        if MediaManager.shared.isPlaying {
            extraWidth += 120
        }
        return CGSize(width: notchSize.width + extraWidth, height: notchSize.height)
    }
    
    func toggleExpand() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)) {
            isExpanded.toggle()
        }
        if isExpanded {
            NSApp.windows.first(where: { $0 is NotchWindow })?.orderFrontRegardless()
        }
    }
    
    func open(tab: NotchTab? = nil) {
        if let tab = tab {
            self.selectedTab = tab
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)) {
            isExpanded = true
        }
        NSApp.windows.first(where: { $0 is NotchWindow })?.orderFrontRegardless()
    }
    
    func close(force: Bool = false) {
        guard force || !isPinned else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0)) {
            isExpanded = false
        }
        NSApp.keyWindow?.resignKey()
    }
}

struct MainNotchView: View {
    @ObservedObject var coordinator = NotchStateCoordinator.shared
    @ObservedObject var shelfManager = ShelfManager.shared
    @ObservedObject var llmTracker = LLMTrackerManager.shared
    @ObservedObject var mediaManager = MediaManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Namespace private var tabAnimation
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main Notch Container - only this shape intercepts hover/clicks
            VStack(spacing: 0) {
                if coordinator.isExpanded {
                    // Physical notch spacer: guarantees all text and tabs start BELOW the physical notch!
                    Color.clear
                        .frame(height: coordinator.notchSize.height + 6)
                    
                    openHeaderView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // Tab Body
                    Group {
                        switch coordinator.selectedTab {
                        case .shelf:
                            ShelfView()
                        case .clipboard:
                            ClipboardView()
                        case .devTools:
                            DevToolsView()
                        case .webTools:
                            WebToolsView()
                        case .myDashboard:
                            MyDashboardView()
                        case .aiQuota:
                            AIQuotaView()
                        case .screenshots:
                            ScreenshotsView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else {
                    closedNotchView
                        .contentShape(Rectangle())
                        .onTapGesture {
                            coordinator.open()
                        }
                }
            }
            .frame(
                width: coordinator.isExpanded ? coordinator.openSize.width : coordinator.currentClosedSize.width,
                height: coordinator.isExpanded ? coordinator.openSize.height : coordinator.currentClosedSize.height
            )
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                    bottomTrailingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(
                    themeManager.currentTheme == .engineeringV2
                        ? AnyShapeStyle(V2Colors.panelGradient)
                        : AnyShapeStyle(Color.black)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                        bottomTrailingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(
                        themeManager.currentTheme == .engineeringV2
                            ? LinearGradient(colors: [Color.white.opacity(0.12), V2Colors.ice.opacity(0.26)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                )
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                    bottomTrailingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                    bottomTrailingRadius: coordinator.isExpanded ? (themeManager.currentTheme == .engineeringV2 ? 22 : 24) : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .onDrop(of: [.fileURL], isTargeted: $shelfManager.isTargeted) { providers in
                coordinator.open(tab: .shelf)
                return shelfManager.handleDrop(providers: providers)
            }
            .shadow(color: (themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.black).opacity(coordinator.isExpanded ? 0.55 : 0.0), radius: 18, x: 0, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0), value: coordinator.isExpanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0), value: coordinator.openSize.height)
        .animation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0), value: mediaManager.isPlaying)
    }
    
    // Header when notch is expanded (positioned cleanly below the physical camera notch)
    // Header when notch is expanded (positioned cleanly below the physical camera notch)
    private var openHeaderView: some View {
        HStack(spacing: 8) {
            tabRailView
            Spacer()
            CompactMusicHUDView()
            pinButton
            collapseButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
    
    private var tabRailView: some View {
        HStack(spacing: 2) {
            tabButton(for: .shelf)
            tabButton(for: .clipboard)
            tabButton(for: .screenshots)
            
            railSeparator
            
            tabButton(for: .devTools)
            tabButton(for: .webTools)
            tabButton(for: .myDashboard)
            tabButton(for: .aiQuota)
            
            railSeparator
            
            tabButton(for: .settings)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    themeManager.currentTheme == .engineeringV2
                        ? AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.065), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.black.opacity(0.65))
                )
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 16, y: 8)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
    }
    
    private var pinFgColor: Color {
        if coordinator.isPinned {
            return themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.orange
        } else {
            return themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.white.opacity(0.6)
        }
    }
    
    private var pinBgColor: Color {
        if coordinator.isPinned {
            return themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.18) : Color.white.opacity(0.15)
        } else {
            return Color.white.opacity(0.04)
        }
    }
    
    private var pinStrokeColor: Color {
        if coordinator.isPinned {
            return themeManager.currentTheme == .engineeringV2 ? V2Colors.ice2.opacity(0.5) : Color.orange.opacity(0.4)
        } else {
            return Color.white.opacity(0.08)
        }
    }

    private var pinButton: some View {
        Button(action: {
            coordinator.isPinned.toggle()
        }) {
            Image(systemName: coordinator.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(pinFgColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(pinBgColor))
                .overlay(Circle().stroke(pinStrokeColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(loc("Pin panel open", "Закрепить панель"))
    }
    
    private var collapseButton: some View {
        Button(action: {
            coordinator.isPinned = false
            coordinator.close()
        }) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.white.opacity(0.6))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.04)))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(loc("Collapse panel", "Свернуть панель"))
    }
    
    @ViewBuilder
    private func tabButton(for tab: NotchTab) -> some View {
        let isSelected = coordinator.selectedTab == tab
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                coordinator.selectedTab = tab
            }
            if tab == .myDashboard {
                Task {
                    await DashboardManager.shared.fetchStats()
                }
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                Text(tab.localizedTitle)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .foregroundStyle(tabTextColor(isSelected: isSelected))
            .background {
                if isSelected {
                    tabActiveBackground
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func tabTextColor(isSelected: Bool) -> Color {
        if isSelected {
            return themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.white
        } else {
            return themeManager.currentTheme == .engineeringV2 ? V2Colors.dim : Color.white.opacity(0.6)
        }
    }
    
    @ViewBuilder
    private var tabActiveBackground: some View {
        if themeManager.currentTheme == .engineeringV2 {
            Capsule()
                .fill(V2Colors.livingIceHGradient)
                .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                .shadow(color: V2Colors.ice.opacity(0.55), radius: 6, y: 1)
                .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
        } else {
            Capsule()
                .fill(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
        }
    }
    
    private var railSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
    }
    
    // Closed Notch View
    private var closedNotchView: some View {
        HStack(spacing: 0) {
            // Left protruding wing (visible outside the physical camera notch)
            if mediaManager.isPlaying {
                HStack(spacing: 3) {
                    Image(systemName: "music.note")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(mediaManager.activeApp == .spotify ? Color.green : Color.pink)
                        .shadow(color: (mediaManager.activeApp == .spotify ? Color.green : Color.pink).opacity(0.6), radius: 3)
                }
                .frame(width: 48, alignment: .center)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            
            // Center span across the physical camera notch
            Spacer(minLength: max(40, coordinator.notchSize.width - 24))
            
            // Right protruding wing (visible outside the physical camera notch)
            if mediaManager.isPlaying {
                HStack(spacing: 3) {
                    LiveWaveformView(
                        isPlaying: true,
                        barColor: mediaManager.activeApp == .spotify ? Color.green : Color.pink,
                        maxHeight: 11
                    )
                }
                .frame(width: 48, alignment: .center)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else if !shelfManager.items.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 8.5))
                    Text("\(shelfManager.items.count)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
    }
}
