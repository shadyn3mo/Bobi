import Foundation
import SwiftUI

// MARK: - Home Status Data Models

/// 主页状态数据聚合结构
struct HomeStatusData {
    let greeting: String
    let weatherInfo: WeatherInfo?
    let dailyCalorieNeeds: Double
    let inventorySnapshot: InventorySnapshot
    let mealSuggestion: MealSuggestion?
    let shoppingStatus: ShoppingStatus
    let lifeTips: [LifeTip]
    let lastUpdated: Date
    
    init(greeting: String = "",
         weatherInfo: WeatherInfo? = nil,
         dailyCalorieNeeds: Double = 0,
         inventorySnapshot: InventorySnapshot = InventorySnapshot(),
         mealSuggestion: MealSuggestion? = nil,
         shoppingStatus: ShoppingStatus = ShoppingStatus(),
         lifeTips: [LifeTip] = [],
         lastUpdated: Date = Date()) {
        self.greeting = greeting
        self.weatherInfo = weatherInfo
        self.dailyCalorieNeeds = dailyCalorieNeeds
        self.inventorySnapshot = inventorySnapshot
        self.mealSuggestion = mealSuggestion
        self.shoppingStatus = shoppingStatus
        self.lifeTips = lifeTips
        self.lastUpdated = lastUpdated
    }
}

/// 天气信息
struct WeatherInfo: Codable, Equatable {
    let temperature: Double
    let condition: WeatherCondition
    let description: String
    let iconName: String
    let location: String?
    let humidity: Double?
    let windSpeed: Double?
    let uvIndex: Int?
    
    init(temperature: Double = 22.0,
         condition: WeatherCondition = .cloudy,
         description: String = "多云",
         iconName: String = "cloud.fill",
         location: String? = nil,
         humidity: Double? = nil,
         windSpeed: Double? = nil,
         uvIndex: Int? = nil) {
        self.temperature = temperature
        self.condition = condition
        self.description = description
        self.iconName = iconName
        self.location = location
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.uvIndex = uvIndex
    }
}

/// 天气状况枚举
enum WeatherCondition: String, CaseIterable, Codable {
    case sunny = "sunny"
    case cloudy = "cloudy"
    case rainy = "rainy"
    case cold = "cold"
    case hot = "hot"
    case windy = "windy"
    case snowy = "snowy"
    
    var localizedName: String {
        switch self {
        case .sunny: return "weather.sunny".localized
        case .cloudy: return "weather.cloudy".localized
        case .rainy: return "weather.rainy".localized
        case .cold: return "weather.cold".localized
        case .hot: return "weather.hot".localized
        case .windy: return "weather.windy".localized
        case .snowy: return "weather.snowy".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .cold: return "thermometer.snowflake"
        case .hot: return "thermometer.sun.fill"
        case .windy: return "wind"
        case .snowy: return "snow"
        }
    }
}

/// 库存快照
struct InventorySnapshot {
    let totalItems: Int
    let expiringItems: [FoodItem]
    let statusDescription: String
    let stockLevel: StockLevel
    let nutritionInsight: String
    
    init(totalItems: Int = 0,
         expiringItems: [FoodItem] = [],
         statusDescription: String = "",
         stockLevel: StockLevel = .sufficient,
         nutritionInsight: String = "") {
        self.totalItems = totalItems
        self.expiringItems = expiringItems
        self.statusDescription = statusDescription
        self.stockLevel = stockLevel
        self.nutritionInsight = nutritionInsight
    }
}

/// 库存水平
enum StockLevel: String, CaseIterable {
    case empty = "empty"
    case low = "low"
    case sufficient = "sufficient"
    case abundant = "abundant"
    
    var localizedName: String {
        switch self {
        case .empty: return "stock.empty".localized
        case .low: return "stock.low".localized
        case .sufficient: return "stock.sufficient".localized
        case .abundant: return "stock.abundant".localized
        }
    }
    
    var color: Color {
        switch self {
        case .empty: return .red
        case .low: return .orange
        case .sufficient: return .green
        case .abundant: return .blue
        }
    }
}

/// 购物状态
struct ShoppingStatus {
    let itemCount: Int
    let urgentItems: [String]
    let estimatedCost: Double
    let hasShortageItems: Bool
    
    init(itemCount: Int = 0,
         urgentItems: [String] = [],
         estimatedCost: Double = 0.0,
         hasShortageItems: Bool = false) {
        self.itemCount = itemCount
        self.urgentItems = urgentItems
        self.estimatedCost = estimatedCost
        self.hasShortageItems = hasShortageItems
    }
}

/// 生活小贴士
struct LifeTip: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
    let type: LifeTipType
    let isRelevant: Bool
    
    init(icon: String = "lightbulb.fill",
         message: String = "",
         type: LifeTipType = .general,
         isRelevant: Bool = true) {
        self.icon = icon
        self.message = message
        self.type = type
        self.isRelevant = isRelevant
    }
    
    static let empty = LifeTip(message: "", isRelevant: false)
}

/// 生活小贴士类型
enum LifeTipType: String, CaseIterable {
    case timeBasedSuggestion = "time_based"
    case weatherBasedSuggestion = "weather_based"
    case encouragement = "encouragement"
    case nutritionTip = "nutrition_tip"
    case general = "general"
    
    var localizedName: String {
        switch self {
        case .timeBasedSuggestion: return "tip.time.based".localized
        case .weatherBasedSuggestion: return "tip.weather.based".localized
        case .encouragement: return "tip.encouragement".localized
        case .nutritionTip: return "tip.nutrition".localized
        case .general: return "tip.general".localized
        }
    }
}