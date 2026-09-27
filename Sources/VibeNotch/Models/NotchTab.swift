import SwiftUI
import AppKit

enum NotchTab: String, CaseIterable, Identifiable {
    case shelf = "Shelf"
    case clipboard = "Buffer"
    case webTools = "Web Apps"
    case myDashboard = "Dashboard"
    case aiQuota = "AI Quota"
    case screenshots = "Shots"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .shelf: return "tray.and.arrow.down.fill"
        case .clipboard: return "doc.on.clipboard.fill"
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
