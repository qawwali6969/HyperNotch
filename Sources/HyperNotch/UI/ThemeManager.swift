import SwiftUI

@MainActor
public enum AppTheme: String, CaseIterable, Identifiable {
    case engineeringV2 = "engineering_v2"
    case classicV1 = "classic_v1"
    
    nonisolated public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .engineeringV2:
            return LocalizationManager.shared.currentLanguage == .russian
                ? "Инженерный прибор (V2 2026)"
                : "Engineering HUD (V2 2026)"
        case .classicV1:
            return LocalizationManager.shared.currentLanguage == .russian
                ? "Классический Нео-Нуар (V1)"
                : "Classic Neo-Noir (V1)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .engineeringV2:
            return LocalizationManager.shared.currentLanguage == .russian
                ? "Жидкий чёрный, градиент «Живой лёд», точечный инструментальный свет"
                : "Liquid black, Living Ice gradient, precision instrument HUD"
        case .classicV1:
            return LocalizationManager.shared.currentLanguage == .russian
                ? "Глубокий монохром, контрастное белое стекло"
                : "Pitch black monochrome, high-contrast white glass"
        }
    }
    
    public var icon: String {
        switch self {
        case .engineeringV2: return "waveform.path.ecg"
        case .classicV1: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - V2 Design Tokens (From V2 HyperNotch — Направление A «Инженерный прибор»)
public struct V2Colors {
    public static let void = Color(hex: "050608")
    public static let bg = Color(hex: "08090C")
    public static let ink = Color(hex: "0A0D11")
    public static let ink2 = Color(hex: "0D1115")
    public static let milk = Color(hex: "EDF3F6")
    public static let dim = Color(hex: "9AA5AD")
    public static let faint = Color(hex: "6B757D")
    public static let ice = Color(hex: "8FB7CC")
    public static let ice1 = Color(hex: "A9CBDD")
    public static let ice2 = Color(hex: "6FA9C4")
    public static let amber = Color(hex: "C7A15E")
    public static let red = Color(hex: "C4645A")
    
    public static var livingIceGradient: LinearGradient {
        LinearGradient(colors: [ice1, ice2], startPoint: .top, endPoint: .bottom)
    }
    
    public static var livingIceHGradient: LinearGradient {
        LinearGradient(colors: [ice1, ice2], startPoint: .leading, endPoint: .trailing)
    }
    
    public static var panelGradient: LinearGradient {
        LinearGradient(colors: [ink, ink2], startPoint: .top, endPoint: .bottom)
    }
}

@MainActor
public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    private let themeKey = "hypernotch_selected_theme"
    
    @Published public var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            // Default is the brand new V2 Engineering HUD!
            self.currentTheme = .engineeringV2
        }
    }
    
    public func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentTheme = theme
        }
    }
}

// MARK: - Color Hex Initializer
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
