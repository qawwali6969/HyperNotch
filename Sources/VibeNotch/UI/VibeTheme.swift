import SwiftUI

// MARK: - Single Unified Tab Container for ALL tabs (Pure deep black, identical typography & spacing)
struct VibeTabContainer<HeaderTrailing: View, Content: View>: View {
    let title: String
    let icon: String
    let headerTrailing: HeaderTrailing
    let content: Content
    
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
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 3)
                    
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
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

// MARK: - VibeTheme Design System (HeroDock standard)
struct HeroGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 13
    var isHovered: Bool = false
    
    func body(content: Content) -> some View {
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

struct HeroCapsuleBarModifier: ViewModifier {
    func body(content: Content) -> some View {
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

struct HeroInputBoxModifier: ViewModifier {
    var cornerRadius: CGFloat = 8
    
    func body(content: Content) -> some View {
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

// MARK: - Native SwiftUI InteractiveHoverButton (Matching MagicUI / 21st.dev)
struct VibeInteractiveHoverButton: View {
    let text: String
    var leadingIcon: String? = nil
    var icon: String = "arrow.right"
    var fontSize: CGFloat = 10
    var horizontalPadding: CGFloat = 9
    var verticalPadding: CGFloat = 4
    var minHeight: CGFloat = 22
    var action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let leading = leadingIcon {
                    Image(systemName: leading)
                        .font(.system(size: max(8, fontSize - 1), weight: .semibold))
                        .foregroundStyle(isHovered ? Color.black : Color.white)
                } else {
                    Circle()
                        .fill(isHovered ? Color.black : Color.white)
                        .frame(width: 4, height: 4)
                }
                
                Text(text)
                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(isHovered ? Color.black : Color.white)
                
                if isHovered {
                    Image(systemName: icon)
                        .font(.system(size: max(8, fontSize - 1), weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background(
                Capsule()
                    .fill(isHovered ? Color.white : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isHovered ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
