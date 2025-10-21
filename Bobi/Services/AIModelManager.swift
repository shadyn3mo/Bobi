import Foundation
import SwiftUI

enum APISource: String, CaseIterable {
    case free = "free"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .free:
            return "ai.source.free.title".localized
        case .custom:
            return "ai.source.custom.title".localized
        }
    }
    
    var description: String {
        switch self {
        case .free:
            return "ai.source.free.description".localized
        case .custom:
            return "ai.source.custom.description".localized
        }
    }
    
    var icon: String {
        switch self {
        case .free:
            return "gift.fill"
        case .custom:
            return "key.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .free:
            return .green
        case .custom:
            return .purple
        }
    }
}

enum APIProvider: String, CaseIterable {
    case openai = "openai"
    case gemini = "gemini"
    case anthropic = "anthropic"
    case deepseek = "deepseek"
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .gemini:
            return "Google Gemini"
        case .anthropic:
            return "Anthropic Claude"
        case .deepseek:
            return "DeepSeek"
        }
    }
    
    var description: String {
        switch self {
        case .openai:
            return "ai.provider.openai.description".localized
        case .gemini:
            return "ai.provider.gemini.description".localized
        case .anthropic:
            return "ai.provider.anthropic.description".localized
        case .deepseek:
            return "ai.provider.deepseek.description".localized
        }
    }
    
    var icon: String {
        switch self {
        case .openai:
            return "message.circle.fill"
        case .gemini:
            return "sparkles"
        case .anthropic:
            return "brain.head.profile"
        case .deepseek:
            return "cpu.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .openai:
            return .green
        case .gemini:
            return .purple
        case .anthropic:
            return .orange
        case .deepseek:
            return .blue
        }
    }
    
    var defaultModel: String {
        switch self {
        case .openai:
            return "gpt-4.1-mini"
        case .gemini:
            return "gemini-2.5-flash"
        case .anthropic:
            return "claude-sonnet-4-20250514"
        case .deepseek:
            return "deepseek-chat"
        }
    }
    
    
    var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .deepseek:
            return "https://api.deepseek.com/v1"
        }
    }
    
}

enum AIModel: String, CaseIterable {
    case deepseekV3 = "deepseek-chat"
    case gpt4mini = "gpt-4.1-mini"
    case geminiFlash = "gemini-2.5-flash"
    
    var displayName: String {
        switch self {
        case .deepseekV3:
            return "Deepseek V3"
        case .gpt4mini:
            return "ChatGPT 4.1 Mini"
        case .geminiFlash:
            return "Gemini 2.5 Flash"
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .deepseekV3:
            return "ai.model.deepseek.description".localized
        case .gpt4mini:
            return "ai.model.gpt4mini.description".localized
        case .geminiFlash:
            return "ai.model.gemini.description".localized
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .deepseekV3:
            return "ai.model.deepseek.detailed".localized
        case .gpt4mini:
            return "ai.model.gpt4mini.detailed".localized
        case .geminiFlash:
            return "ai.model.gemini.detailed".localized
        }
    }
    
    var icon: String {
        switch self {
        case .deepseekV3:
            return "brain.head.profile"
        case .gpt4mini:
            return "message.fill"
        case .geminiFlash:
            return "sparkle"
        }
    }
    
    var color: Color {
        switch self {
        case .deepseekV3:
            return .blue
        case .gpt4mini:
            return .green
        case .geminiFlash:
            return .purple
        }
    }
}

class AIModelManager: ObservableObject {
    static let shared = AIModelManager()
    
    @Published var selectedModel: AIModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedAIModel")
        }
    }
    
    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: "aiTemperature")
        }
    }
    
    @Published var apiSource: APISource {
        didSet {
            UserDefaults.standard.set(apiSource.rawValue, forKey: "selectedAPISource")
        }
    }
    
    @Published var apiProvider: APIProvider {
        didSet {
            UserDefaults.standard.set(apiProvider.rawValue, forKey: "selectedAPIProvider")
        }
    }
    
    
    @Published var customAPIKey: String {
        didSet {
            UserDefaults.standard.set(customAPIKey, forKey: "customAPIKey")
        }
    }
    
    var isUsingCustomAPI: Bool {
        return apiSource == .custom
    }
    
    var currentAPIKey: String {
        switch apiSource {
        case .free:
            return ""
        case .custom:
            return customAPIKey
        }
    }
    
    var currentBaseURL: String {
        switch apiSource {
        case .free:
            return ""
        case .custom:
            return apiProvider.baseURL
        }
    }
    
    var currentModelName: String {
        switch apiSource {
        case .free:
            return "gemini-2.0-flash"
        case .custom:
            return apiProvider.defaultModel
        }
    }
    
    var currentProvider: APIProvider {
        return apiProvider
    }
    
    private init() {
        if let savedModel = UserDefaults.standard.string(forKey: "selectedAIModel"),
           let model = AIModel(rawValue: savedModel) {
            self.selectedModel = model
        } else {
            self.selectedModel = .deepseekV3
        }
        
        let savedTemp = UserDefaults.standard.double(forKey: "aiTemperature")
        if savedTemp > 0 {
            self.temperature = savedTemp
        } else {
            self.temperature = 0.7
        }
        
        if let savedAPISource = UserDefaults.standard.string(forKey: "selectedAPISource"),
           let apiSource = APISource(rawValue: savedAPISource) {
            self.apiSource = apiSource
        } else if UserDefaults.standard.string(forKey: "selectedAPISource") == "cloud" {
            // 兼容旧版本的cloud设置
            self.apiSource = .free
        } else {
            self.apiSource = .free
        }
        
        if let savedAPIProvider = UserDefaults.standard.string(forKey: "selectedAPIProvider"),
           let apiProvider = APIProvider(rawValue: savedAPIProvider) {
            self.apiProvider = apiProvider
        } else {
            self.apiProvider = .openai
        }
        
        self.customAPIKey = UserDefaults.standard.string(forKey: "customAPIKey") ?? ""
    }
}