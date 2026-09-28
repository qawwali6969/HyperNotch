import SwiftUI
import AppKit

enum NotchTab: String, CaseIterable, Identifiable {
    case shelf = "Shelf"
    case clipboard = "Buffer"
    case devTools = "Dev"
    case webTools = "Web Apps"
    case myDashboard = "Dashboard"
    case aiQuota = "AI Quota"
    case screenshots = "Shots"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    @MainActor
    var localizedTitle: String {
        switch self {
        case .shelf: return loc("Shelf", "Полка")
        case .clipboard: return loc("Buffer", "Буфер")
        case .devTools: return loc("Dev Tools", "Дев")
        case .webTools: return loc("Web Apps", "Веб")
        case .myDashboard: return loc("Dashboard", "Дашборд")
        case .aiQuota: return loc("AI Quota", "Квоты AI")
        case .screenshots: return loc("Shots", "Снимки")
        case .settings: return loc("Settings", "Настройки")
        }
    }
    
    var icon: String {
        switch self {
        case .shelf: return "tray.and.arrow.down.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .devTools: return "curlybraces"
        case .webTools: return "globe"
        case .myDashboard: return "chart.xyaxis.line"
        case .aiQuota: return "sparkles"
        case .screenshots: return "camera.viewfinder"
        case .settings: return "gearshape.fill"
        }
    }
}

enum NotchState {
    case closed
    case open
}
