import SwiftUI
import AppKit

enum NotchTier: String, CaseIterable {
    case ingest = "ingest"
    case system = "system"
    case service = "service"
    
    @MainActor
    var localizedTitle: String {
        switch self {
        case .ingest: return loc("Ingest", "Приём")
        case .system: return loc("System", "Контур")
        case .service: return loc("Service", "Сервис")
        }
    }
}

enum NotchTab: String, CaseIterable, Identifiable {
    case shelf = "Shelf"
    case clipboard = "Buffer"
    case screenshots = "Shots"
    case devTools = "Dev"
    case webTools = "Web Apps"
    case myDashboard = "Dashboard"
    case aiQuota = "AI Quota"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var indexString: String {
        switch self {
        case .shelf: return "01"
        case .clipboard: return "02"
        case .screenshots: return "03"
        case .devTools: return "04"
        case .webTools: return "05"
        case .myDashboard: return "06"
        case .aiQuota: return "07"
        case .settings: return "08"
        }
    }
    
    var tier: NotchTier {
        switch self {
        case .shelf, .clipboard, .screenshots: return .ingest
        case .devTools, .webTools, .myDashboard, .aiQuota: return .system
        case .settings: return .service
        }
    }
    
    @MainActor
    var localizedTitle: String {
        switch self {
        case .shelf: return loc("Shelf", "Полка")
        case .clipboard: return loc("Buffer", "Буфер")
        case .screenshots: return loc("Shots", "Снимки")
        case .devTools: return loc("Dev Tools", "Дев")
        case .webTools: return loc("Web Apps", "Веб")
        case .myDashboard: return loc("Dashboard", "Дашборд")
        case .aiQuota: return loc("AI Quota", "Квоты AI")
        case .settings: return loc("Settings", "Настройки")
        }
    }
    
    var icon: String {
        switch self {
        case .shelf: return "tray.and.arrow.down.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .screenshots: return "camera.viewfinder"
        case .devTools: return "curlybraces"
        case .webTools: return "globe"
        case .myDashboard: return "chart.xyaxis.line"
        case .aiQuota: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}

enum NotchState {
    case closed
    case open
}
