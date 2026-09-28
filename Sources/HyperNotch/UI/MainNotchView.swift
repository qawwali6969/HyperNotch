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
    }
    
    func open(tab: NotchTab? = nil) {
        if let tab = tab {
            self.selectedTab = tab
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)) {
            isExpanded = true
        }
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
            .background(Color.black)
            .clipShape(BottomRoundedRectangle(radius: coordinator.isExpanded ? 24 : 14))
            .contentShape(BottomRoundedRectangle(radius: coordinator.isExpanded ? 24 : 14))
            .onDrop(of: [.fileURL], isTargeted: $shelfManager.isTargeted) { providers in
                coordinator.open(tab: .shelf)
                return shelfManager.handleDrop(providers: providers)
            }
            .shadow(color: .black.opacity(coordinator.isExpanded ? 0.45 : 0.0), radius: 15, x: 0, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0), value: coordinator.isExpanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0), value: coordinator.openSize.height)
        .animation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0), value: mediaManager.isPlaying)
    }
    
    // Header when notch is expanded (positioned cleanly below the physical camera notch)
    private var openHeaderView: some View {
        HStack(spacing: 8) {
            // Tab Buttons - strictly fixed horizontal layout, never breaks into vertical letters
            HStack(spacing: 2) {
                ForEach(NotchTab.allCases) { tab in
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
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            Text(tab.localizedTitle)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                        .shadow(color: isSelected ? Color.white.opacity(0.3) : Color.clear, radius: 4)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.12)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.65))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            
            Spacer()
            
            // Music HUD
            CompactMusicHUDView()
            
            // Pin Toggle Button
            Button(action: {
                coordinator.isPinned.toggle()
            }) {
                Image(systemName: coordinator.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(coordinator.isPinned ? Color.orange : Color.white.opacity(0.6))
                    .padding(4)
                    .background(Circle().fill(Color.white.opacity(coordinator.isPinned ? 0.15 : 0.05)))
            }
            .buttonStyle(.plain)
            
            // Collapse Button
            Button(action: {
                coordinator.isPinned = false
                coordinator.close()
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(4)
                    .background(Circle().fill(Color.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 6)
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
