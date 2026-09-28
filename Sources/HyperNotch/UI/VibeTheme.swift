import SwiftUI

// MARK: - Single Unified Tab Container for ALL tabs (Pure deep black, identical typography & spacing)
struct VibeTabContainer<HeaderTrailing: View, Content: View>: View {
    let title: String
    let icon: String
    let headerTrailing: HeaderTrailing
    let content: Content
    @ObservedObject var themeManager = ThemeManager.shared
    
    init(
        title: String,
        icon: String,
        @ViewBuilder headerTrailing: () -> HeaderTrailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.headerTrailing = headerTrailing()
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Standard Global Header
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                    
                    Text(title.uppercased())
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
                }
                
                Spacer()
                
                headerTrailing
            }
            .padding(.horizontal, 16)
            
            // Tab Body Content
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.black)
    }
}

extension VibeTabContainer where HeaderTrailing == EmptyView {
    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, icon: icon, headerTrailing: { EmptyView() }, content: content)
    }
}

// MARK: - VibeTheme Design System (V2 Engineering HUD + V1 Classic)
struct HeroGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 13
    var isHovered: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        if themeManager.currentTheme == .engineeringV2 {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "0D1217").opacity(isHovered ? 0.95 : 0.85),
                                    Color(hex: "090D10").opacity(isHovered ? 0.98 : 0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isHovered ? 0.24 : 0.08),
                                            V2Colors.ice.opacity(isHovered ? 0.36 : 0.12)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color(hex: "050608").opacity(isHovered ? 0.55 : 0.38), radius: isHovered ? 12 : 7, y: isHovered ? 4 : 2)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.16).opacity(isHovered ? 0.92 : 0.75),
                                    Color(white: 0.08).opacity(isHovered ? 0.95 : 0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(isHovered ? 0.35 : 0.16),
                                            Color.white.opacity(isHovered ? 0.15 : 0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(isHovered ? 0.5 : 0.35), radius: isHovered ? 12 : 7, y: isHovered ? 4 : 2)
                )
        }
    }
}

struct HeroCapsuleBarModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        if themeManager.currentTheme == .engineeringV2 {
            content
                .background(
                    Capsule()
                        .fill(V2Colors.ink.opacity(0.92))
                        .overlay(
                            Capsule().stroke(V2Colors.ice.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color(hex: "050608").opacity(0.55), radius: 14, y: 5)
                )
        } else {
            content
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 14, y: 5)
                )
        }
    }
}

struct HeroInputBoxModifier: ViewModifier {
    var cornerRadius: CGFloat = 8
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        if themeManager.currentTheme == .engineeringV2 {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(V2Colors.ink2.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(V2Colors.ice.opacity(0.16), lineWidth: 1)
                        )
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
        }
    }
}

extension View {
    func heroGlassCard(cornerRadius: CGFloat = 13, isHovered: Bool = false) -> some View {
        self.modifier(HeroGlassCardModifier(cornerRadius: cornerRadius, isHovered: isHovered))
    }
    
    func heroCapsuleBar() -> some View {
        self.modifier(HeroCapsuleBarModifier())
    }
    
    func heroInputBox(cornerRadius: CGFloat = 8) -> some View {
        self.modifier(HeroInputBoxModifier(cornerRadius: cornerRadius))
    }
}

struct VibeInteractiveHoverButton: View {
    let text: String
    var leadingIcon: String? = nil
    var icon: String = "arrow.right"
    var fontSize: CGFloat = 10
    var horizontalPadding: CGFloat = 9
    var verticalPadding: CGFloat = 4
    var minHeight: CGFloat = 22
    var action: () -> Void
    
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let leading = leadingIcon {
                    Image(systemName: leading)
                        .font(.system(size: max(8, fontSize - 1), weight: .semibold))
                        .foregroundStyle(isHovered ? (themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.black) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white))
                } else {
                    Circle()
                        .fill(isHovered ? (themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.black) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white))
                        .frame(width: 4, height: 4)
                }
                
                Text(text)
                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(isHovered ? (themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.black) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white))
                
                if isHovered {
                    Image(systemName: icon)
                        .font(.system(size: max(8, fontSize - 1), weight: .bold))
                        .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? Color(hex: "050608") : Color.black)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background {
                if isHovered {
                    if themeManager.currentTheme == .engineeringV2 {
                        V2Colors.livingIceHGradient
                            .clipShape(Capsule())
                    } else {
                        Color.white
                            .clipShape(Capsule())
                    }
                } else {
                    (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.12) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .overlay(
                Capsule()
                    .stroke(isHovered ? (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice2 : Color.white) : (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.25) : Color.white.opacity(0.18)), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - V2 Module Header & Glass Button (Matching V2 Engineering HUD)
struct V2ModuleHeader<TrailingContent: View>: View {
    let tab: NotchTab
    let statusText: String
    let trailing: TrailingContent
    @ObservedObject var themeManager = ThemeManager.shared
    
    init(tab: NotchTab, statusText: String, @ViewBuilder trailing: () -> TrailingContent) {
        self.tab = tab
        self.statusText = statusText
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Index (01, 02...)
            Text(tab.indexString)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.secondary)
            
            // Title
            Text(tab.localizedTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
            
            // Tier Badge (Приём / Контур / Сервис)
            Text(tab.tier.localizedTitle.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.dim : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.10) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice.opacity(0.22) : Color.white.opacity(0.15), lineWidth: 1)
                )
            
            Spacer()
            
            // Dynamic Status Text
            Text(statusText.uppercased())
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.secondary)
                .lineLimit(1)
            
            trailing
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
    }
}

extension V2ModuleHeader where TrailingContent == EmptyView {
    init(tab: NotchTab, statusText: String) {
        self.init(tab: tab, statusText: statusText, trailing: { EmptyView() })
    }
}

struct V2GlassButton: View {
    let title: String
    var icon: String? = nil
    var isKey: Bool = false
    var action: () -> Void
    
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isHovered = false
    
    private var fgColor: Color {
        if isHovered {
            return themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white
        } else {
            return themeManager.currentTheme == .engineeringV2 ? (isKey ? V2Colors.milk : V2Colors.dim) : Color.white.opacity(0.7)
        }
    }
    
    private var bgColor: Color {
        if themeManager.currentTheme == .engineeringV2 {
            return isHovered ? V2Colors.ice.opacity(0.22) : (isKey ? V2Colors.ice.opacity(0.15) : V2Colors.ice.opacity(0.06))
        } else {
            return Color.white.opacity(isHovered ? 0.18 : 0.08)
        }
    }
    
    private var strokeColor: Color {
        if themeManager.currentTheme == .engineeringV2 {
            return isHovered ? V2Colors.ice2.opacity(0.5) : (isKey ? V2Colors.ice.opacity(0.35) : V2Colors.ice.opacity(0.16))
        } else {
            return Color.white.opacity(isHovered ? 0.3 : 0.12)
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 9.5, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(fgColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(RoundedRectangle(cornerRadius: 6).fill(bgColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - V2 Chip (Capsule Status Indicator)
enum V2ChipStyle {
    case ice
    case warn
    case crit
    case dim
}

struct V2Chip: View {
    let text: String
    var style: V2ChipStyle = .dim
    var icon: String? = nil
    @ObservedObject var themeManager = ThemeManager.shared
    
    init(_ text: String, style: V2ChipStyle = .dim, icon: String? = nil) {
        self.text = text
        self.style = style
        self.icon = icon
    }
    
    private var fgColor: Color {
        if themeManager.currentTheme == .engineeringV2 {
            switch style {
            case .ice: return Color(hex: "BFDCEA")
            case .warn: return V2Colors.amber
            case .crit: return V2Colors.red
            case .dim: return V2Colors.dim
            }
        } else {
            switch style {
            case .ice: return .cyan
            case .warn: return .orange
            case .crit: return .red
            case .dim: return .secondary
            }
        }
    }
    
    private var bgColor: Color {
        if themeManager.currentTheme == .engineeringV2 {
            switch style {
            case .ice: return Color(hex: "8FB7CC").opacity(0.14)
            case .warn: return V2Colors.amber.opacity(0.12)
            case .crit: return V2Colors.red.opacity(0.12)
            case .dim: return Color.white.opacity(0.04)
            }
        } else {
            return fgColor.opacity(0.15)
        }
    }
    
    private var borderColor: Color {
        if themeManager.currentTheme == .engineeringV2 {
            switch style {
            case .ice: return Color(hex: "8FB7CC").opacity(0.32)
            case .warn: return V2Colors.amber.opacity(0.32)
            case .crit: return V2Colors.red.opacity(0.34)
            case .dim: return Color.white.opacity(0.12)
            }
        } else {
            return fgColor.opacity(0.3)
        }
    }
    
    var body: some View {
        HStack(spacing: 3.5) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .foregroundStyle(fgColor)
        .background(Capsule().fill(bgColor))
        .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }
}

// MARK: - V2 Gauge Bar (Instrument Meter)
struct V2Gauge: View {
    let progress: Double // 0.0 to 1.0
    var isWarning: Bool = false
    var isCritical: Bool = false
    @ObservedObject var themeManager = ThemeManager.shared
    
    init(progress: Double, isWarning: Bool = false, isCritical: Bool = false) {
        self.progress = max(0, min(1, progress))
        self.isWarning = isWarning
        self.isCritical = isCritical
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                
                // Progress fill
                Capsule()
                    .fill(
                        isCritical
                            ? AnyShapeStyle(V2Colors.red)
                            : (isWarning
                                ? AnyShapeStyle(V2Colors.amber)
                                : (themeManager.currentTheme == .engineeringV2
                                    ? AnyShapeStyle(V2Colors.livingIceHGradient)
                                    : AnyShapeStyle(Color.white.opacity(0.85))))
                    )
                    .frame(width: max(4, geo.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 5)
    }
}

