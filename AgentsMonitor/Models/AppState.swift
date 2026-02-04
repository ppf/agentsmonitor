import Foundation
import SwiftUI

@Observable
final class AppState {
    var isSidebarVisible: Bool = true
    var selectedDetailTab: DetailTab = .terminal
    var searchText: String = ""
    var filterStatus: SessionStatus? = nil
    var sortOrder: SortOrder = .newest
    var appearance: AppAppearance = .system
    var refreshInterval: TimeInterval = 5.0
    var showMenuBarExtra: Bool = true
    var compactMode: Bool = false

    enum DetailTab: String, CaseIterable {
        case terminal = "Terminal"
        case toolCalls = "Tool Calls"
        case metrics = "Metrics"

        var icon: String {
            switch self {
            case .terminal: return "terminal"
            case .toolCalls: return "wrench.and.screwdriver"
            case .metrics: return "chart.bar"
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case name = "Name"
        case status = "Status"
    }

    enum AppAppearance: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }
}
