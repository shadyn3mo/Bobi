import SwiftUI

enum AppTheme: String, CaseIterable {
    case auto = "auto"
    case light = "light" 
    case dark = "dark"
    
    var localizedName: String {
        switch self {
        case .auto: return "interface.auto".localized
        case .light: return "interface.light".localized
        case .dark: return "interface.dark".localized
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
class ThemeManager {
    static let shared = ThemeManager()
    
    var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
            print("Theme changed to: \(selectedTheme.rawValue)")
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.auto.rawValue
        self.selectedTheme = AppTheme(rawValue: savedTheme) ?? .auto
        print("ThemeManager initialized with theme: \(selectedTheme.rawValue)")
    }
}