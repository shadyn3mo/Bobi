//
//  EnhancedGreetingService.swift
//  Bobi
//
//  增强的问候语服务，提供更丰富和细分的问候语内容
//

import Foundation

// MARK: - Enhanced Greeting Service

/// 增强的问候语服务，提供基于时间、天气、心情、季节等多维度的个性化问候语
@MainActor
class EnhancedGreetingService: ObservableObject {
    static let shared = EnhancedGreetingService()
    
    private let localizationManager = LocalizationManager.shared
    
    private init() {}
    
    /// 生成增强的个性化问候语
    func generateEnhancedGreeting(
        weather: WeatherInfo? = nil,
        mood: UserMood? = nil,
        isFirstLaunchToday: Bool = false
    ) async -> String {
        
        let context = GreetingContext(
            hour: Calendar.current.component(.hour, from: Date()),
            isWeekend: Calendar.current.isDateInWeekend(Date()),
            season: getCurrentGreetingSeason(),
            weather: weather,
            mood: mood,
            isFirstLaunchToday: isFirstLaunchToday
        )
        
        return generateContextualGreeting(context)
    }
    
    // MARK: - Private Methods
    
    /// 根据上下文生成问候语
    private func generateContextualGreeting(_ context: GreetingContext) -> String {
        let timeOfDay = getTimeOfDay(context.hour)
        let language = localizationManager.selectedLanguage
        
        // 选择最合适的问候语
        if let weather = context.weather {
            return generateWeatherAwareGreeting(timeOfDay: timeOfDay, weather: weather, context: context, language: language)
        } else if let mood = context.mood {
            return generateMoodAwareGreeting(timeOfDay: timeOfDay, mood: mood, context: context, language: language)
        } else {
            return generateEnhancedTimeGreeting(timeOfDay: timeOfDay, context: context, language: language)
        }
    }
    
    /// 生成天气感知的问候语
    private func generateWeatherAwareGreeting(
        timeOfDay: TimeOfDay,
        weather: WeatherInfo,
        context: GreetingContext,
        language: String
    ) -> String {
        let baseKey = "enhanced.greeting.\(timeOfDay.rawValue).\(weather.condition.rawValue)"
        
        // 尝试特定的天气问候语
        if let specificGreeting = getLocalizedGreeting(key: baseKey, language: language) {
            return applyContextualEnhancement(specificGreeting, context: context, language: language)
        }
        
        // 回退到基础时间问候语
        return generateEnhancedTimeGreeting(timeOfDay: timeOfDay, context: context, language: language)
    }
    
    /// 生成心情感知的问候语
    private func generateMoodAwareGreeting(
        timeOfDay: TimeOfDay,
        mood: UserMood,
        context: GreetingContext,
        language: String
    ) -> String {
        let baseKey = "enhanced.greeting.\(timeOfDay.rawValue).\(mood.mood.rawValue)"
        
        // 尝试特定的心情问候语
        if let specificGreeting = getLocalizedGreeting(key: baseKey, language: language) {
            return applyContextualEnhancement(specificGreeting, context: context, language: language)
        }
        
        // 回退到基础时间问候语
        return generateEnhancedTimeGreeting(timeOfDay: timeOfDay, context: context, language: language)
    }
    
    /// 生成增强的时间问候语
    private func generateEnhancedTimeGreeting(
        timeOfDay: TimeOfDay,
        context: GreetingContext,
        language: String
    ) -> String {
        let variations = getTimeGreetingVariations(timeOfDay: timeOfDay, context: context, language: language)
        
        // 根据日期选择变化，确保同一天不重复
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let selectedIndex = dayOfYear % variations.count
        
        return applyContextualEnhancement(variations[selectedIndex], context: context, language: language)
    }
    
    /// 获取时间问候语变化
    private func getTimeGreetingVariations(
        timeOfDay: TimeOfDay,
        context: GreetingContext,
        language: String
    ) -> [String] {
        let baseKey = "enhanced.greeting.\(timeOfDay.rawValue)"
        let weekendSuffix = context.isWeekend ? ".weekend" : ".weekday"
        let seasonSuffix = ".\(context.season.rawValue)"
        
        var variations: [String] = []
        
        // 优先级：季节+工作日类型 > 工作日类型 > 基础
        for suffix in [seasonSuffix + weekendSuffix, weekendSuffix, ""] {
            for i in 1...5 { // 每个类型最多5个变化
                let key = baseKey + suffix + ".\(i)"
                if let greeting = getLocalizedGreeting(key: key, language: language) {
                    variations.append(greeting)
                }
            }
            if !variations.isEmpty { break } // 找到变化就使用，否则继续尝试更简单的键
        }
        
        // 确保至少有一个问候语
        if variations.isEmpty {
            let fallbackKey = timeOfDay == .morning ? 
                (context.isWeekend ? "weekend.morning.greeting" : "weekday.morning.greeting") :
                "\(timeOfDay.rawValue).greeting"
            variations.append(getLocalizedGreeting(key: fallbackKey, language: language) ?? "Hello!")
        }
        
        return variations
    }
    
    /// 应用上下文增强
    private func applyContextualEnhancement(
        _ baseGreeting: String,
        context: GreetingContext,
        language: String
    ) -> String {
        var enhanced = baseGreeting
        
        // 添加季节性装饰
        if let seasonEmoji = context.season.emoji {
            enhanced = "\(seasonEmoji) \(enhanced)"
        }
        
        
        return enhanced
    }
    
    /// 获取本地化问候语
    private func getLocalizedGreeting(key: String, language: String) -> String? {
        let localized = key.localized
        return localized != key ? localized : nil // 如果没有找到本地化，返回nil
    }
    
    /// 获取当前时间段
    private func getTimeOfDay(_ hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<9: return .earlyMorning
        case 9..<12: return .morning
        case 12..<14: return .noon
        case 14..<17: return .afternoon
        case 17..<19: return .earlyEvening
        case 19..<22: return .evening
        case 22..<24, 0..<5: return .night
        default: return .morning
        }
    }
    
    /// 获取当前季节
    private func getCurrentGreetingSeason() -> GreetingSeason {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        case 12, 1, 2: return .winter
        default: return .spring
        }
    }
}

// MARK: - Supporting Models

/// 问候语上下文
struct GreetingContext {
    let hour: Int
    let isWeekend: Bool
    let season: GreetingSeason
    let weather: WeatherInfo?
    let mood: UserMood?
    let isFirstLaunchToday: Bool
}

/// 时间段枚举
enum TimeOfDay: String, CaseIterable {
    case earlyMorning = "early_morning"    // 5-9点
    case morning = "morning"               // 9-12点
    case noon = "noon"                     // 12-14点
    case afternoon = "afternoon"           // 14-17点
    case earlyEvening = "early_evening"    // 17-19点
    case evening = "evening"               // 19-22点
    case night = "night"                   // 22-5点
}

/// 季节枚举
enum GreetingSeason: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
    
    var emoji: String? {
        switch self {
        case .spring: return "🌸"
        case .summer: return "☀️"
        case .autumn: return "🍂"
        case .winter: return "❄️"
        }
    }
}

// MARK: - Extensions

