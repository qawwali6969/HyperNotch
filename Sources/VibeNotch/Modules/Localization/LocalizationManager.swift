import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        }
    }
    
    public var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .russian: return "🇷🇺"
        }
    }
}

@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    private let storageKey = "vibenotch_app_language"
    
    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: storageKey)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // English by default
            self.currentLanguage = .english
        }
    }
    
    public func setLanguage(_ lang: AppLanguage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.currentLanguage = lang
        }
    }
    
    public var isRussian: Bool {
        currentLanguage == .russian
    }
    
    public func localized(_ en: String, _ ru: String) -> String {
        currentLanguage == .russian ? ru : en
    }
}

/// Shorthand helper for bilingual string resolution across SwiftUI views
@MainActor
public func loc(_ en: String, _ ru: String) -> String {
    LocalizationManager.shared.localized(en, ru)
}
