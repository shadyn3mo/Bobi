import Foundation
import SwiftUI

@Observable
class LocalizationManager {
    var selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en" {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
    }
    
    static let shared = LocalizationManager()
    
    private init() {}
    
    // Language bundles for dynamic language switching
    private var languageBundles: [String: Bundle] = [:]
    
    private func getBundle(for language: String) -> Bundle {
        if let bundle = languageBundles[language] {
            return bundle
        }
        
        let path = Bundle.main.path(forResource: language, ofType: "lproj") ?? Bundle.main.bundlePath
        let bundle = Bundle(path: path) ?? Bundle.main
        languageBundles[language] = bundle
        return bundle
    }
    
    func localizedString(for key: String) -> String {
        // Get localized string from standard .strings files
        let bundle = getBundle(for: selectedLanguage)
        let localized = bundle.localizedString(forKey: key, value: "___NOT_FOUND___", table: nil)
        
        // If found in .strings file, use it
        if localized != "___NOT_FOUND___" {
            return localized
        }
        
        // Try English fallback in .strings
        if selectedLanguage != "en" {
            let englishBundle = getBundle(for: "en")
            let englishLocalized = englishBundle.localizedString(forKey: key, value: "___NOT_FOUND___", table: nil)
            if englishLocalized != "___NOT_FOUND___" {
                return englishLocalized
            }
        }
        
        // Last resort: return the key itself
        return key
    }
    
    func localizedString(for key: String, with arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }
}

extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return LocalizationManager.shared.localizedString(for: self, with: arguments)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
    static let homeStatusDataUpdated = Notification.Name("homeStatusDataUpdated")
}