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
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                        .shadow(color: (themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white).opacity(0.4), radius: 3)
                    
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
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
        .background(themeManager.currentTheme == .engineeringV2 ? V2Colors.void : Color.black)
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
