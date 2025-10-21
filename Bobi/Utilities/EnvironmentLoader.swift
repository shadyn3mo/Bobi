import Foundation

class EnvironmentLoader {
    static let shared = EnvironmentLoader()
    
    private var configVars: [String: Any] = [:]
    
    private init() {
        loadPlistFile()
    }
    
    private func loadPlistFile() {
        guard let path = Bundle.main.path(forResource: "GenAI", ofType: "plist") else {
            return
        }
        
        guard let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return
        }
        
        configVars = plist
    }
    
    func getValue(for key: String) -> String? {
        return configVars[key] as? String
    }
    
    func getIntValue(for key: String) -> Int? {
        return configVars[key] as? Int
    }
    
    var geminiAPIKey: String? {
        let key = getValue(for: "GEMINI")
        
        if key == "your_gemini_api_key_here" || key?.isEmpty == true {
            return nil
        }
        
        return key
    }
    
    var freeAIDailyLimit: Int {
        return getIntValue(for: "FREE_AI_DAILY_LIMIT") ?? 10
    }
}