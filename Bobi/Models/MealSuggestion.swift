import Foundation
import SwiftUI

// MARK: - Nutrition Data Model

/// 营养数据模型
struct NutritionData: Codable, Equatable {
    let protein: Double // 蛋白质 (g)
    let carbs: Double   // 碳水化合物 (g)
    let fat: Double     // 脂肪 (g)
    let fiber: Double   // 纤维 (g)
    let calories: Double // 热量 (kcal)
    
    init(protein: Double = 0, carbs: Double = 0, fat: Double = 0, fiber: Double = 0, calories: Double = 0) {
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.calories = calories
    }
}

// MARK: - Meal Suggestion Model

/// 膳食建议模型
struct MealSuggestion: Identifiable, Codable, Equatable {
    let id: UUID
    let dishName: String
    let reason: String
    let cookingTime: Int
    let difficulty: DifficultyLevel
    let suitability: String
    let ingredients: [String]
    let urgency: UrgencyLevel
    let mealType: MealType
    let nutritionHighlights: [String]
    let recipePreview: String
    let cookingSteps: [String]
    let nutritionData: NutritionData?
    let createdAt: Date
    
    init(dishName: String,
         reason: String,
         cookingTime: Int = 30,
         difficulty: DifficultyLevel = .easy,
         suitability: String = "family.suitable".localized,
         ingredients: [String] = [],
         urgency: UrgencyLevel = .normal,
         mealType: MealType = .dinner,
         nutritionHighlights: [String] = [],
         recipePreview: String = "",
         cookingSteps: [String] = [],
         nutritionData: NutritionData? = nil,
         createdAt: Date = Date()) {
        self.id = UUID()
        self.dishName = dishName
        self.reason = reason
        self.cookingTime = cookingTime
        self.difficulty = difficulty
        self.suitability = suitability
        self.ingredients = ingredients
        self.urgency = urgency
        self.mealType = mealType
        self.nutritionHighlights = nutritionHighlights
        self.recipePreview = recipePreview
        self.cookingSteps = cookingSteps
        self.nutritionData = nutritionData
        self.createdAt = createdAt
    }
}

/// 难度级别
enum DifficultyLevel: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var localizedName: String {
        switch self {
        case .easy: return "difficulty.easy".localized
        case .medium: return "difficulty.medium".localized
        case .hard: return "difficulty.hard".localized
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .easy: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "star.fill"
        }
    }
}

/// 紧急程度
enum UrgencyLevel: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    
    var localizedName: String {
        switch self {
        case .low: return "urgency.low".localized
        case .normal: return "urgency.normal".localized
        case .high: return "urgency.high".localized
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .normal: return .primary
        case .high: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .normal: return "clock.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}

/// 餐食类型
enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    case dessert = "dessert"
    
    var localizedName: String {
        switch self {
        case .breakfast: return "meal.breakfast".localized
        case .lunch: return "meal.lunch".localized
        case .dinner: return "meal.dinner".localized
        case .snack: return "meal.snack".localized
        case .dessert: return "meal.dessert".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        case .dessert: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .indigo
        case .snack: return .green
        case .dessert: return .pink
        }
    }
    
    /// 根据当前时间获取推荐的餐食类型
    static func getCurrentMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6...10:
            return .breakfast
        case 11...13:
            return .lunch
        case 17...21:
            return .dinner
        default:
            return .snack
        }
    }
}

// MARK: - Meal Suggestion Extensions

extension MealSuggestion {
    /// 获取显示用的烹饪时间文本
    var cookingTimeText: String {
        if cookingTime <= 15 {
            return String(format: "cooking.time.quick".localized, cookingTime)
        } else if cookingTime <= 30 {
            return String(format: "cooking.time.medium".localized, cookingTime)
        } else {
            return String(format: "cooking.time.long".localized, cookingTime)
        }
    }
    
    /// 获取综合评分（用于排序）
    var priorityScore: Int {
        var score = 0
        
        // 紧急程度权重
        switch urgency {
        case .high: score += 100
        case .normal: score += 50
        case .low: score += 25
        }
        
        // 难度权重（简单的优先）
        switch difficulty {
        case .easy: score += 30
        case .medium: score += 20
        case .hard: score += 10
        }
        
        // 烹饪时间权重（快速的优先）
        if cookingTime <= 15 {
            score += 20
        } else if cookingTime <= 30 {
            score += 15
        } else {
            score += 10
        }
        
        return score
    }
    
    /// 是否适合当前时间
    var isAppropriateForCurrentTime: Bool {
        let currentMealType = MealType.getCurrentMealType()
        return self.mealType == currentMealType || self.mealType == .snack
    }
}

// MARK: - Mock Data for Testing

extension MealSuggestion {
    /// 创建模拟数据用于测试
    static let mockSuggestions: [MealSuggestion] = [
        MealSuggestion(
            dishName: "蒜蓉牛肉炒河粉",
            reason: "优先使用即将过期的牛肉",
            cookingTime: 15,
            difficulty: .easy,
            suitability: "全家适宜",
            ingredients: ["牛肉", "河粉", "蒜蓉", "豆芽菜"],
            urgency: .high,
            mealType: .dinner,
            nutritionHighlights: ["nutrition.highlight.high_protein".localized, "nutrition.highlight.low_fat".localized],
            recipePreview: "热锅下油，爆炒蒜蓉至香，加入牛肉丝炒至变色...",
            cookingSteps: ["准备食材，牛肉切丝腌制", "热锅下油，爆炒蒜蓉", "下牛肉丝炒至变色", "加入河粉和豆芽菜炒匀"],
            nutritionData: NutritionData(protein: 25.5, carbs: 45.2, fat: 12.3, fiber: 3.1, calories: 385)
        ),
        MealSuggestion(
            dishName: "番茄鸡蛋面",
            reason: "简单营养的家常菜",
            cookingTime: 20,
            difficulty: .easy,
            suitability: "老少皆宜",
            ingredients: ["鸡蛋", "番茄", "面条", "葱花"],
            urgency: .normal,
            mealType: .lunch,
            nutritionHighlights: ["nutrition.highlight.vitamin_c".localized, "nutrition.highlight.high_protein".localized],
            recipePreview: "番茄切块，热锅炒蛋盛起，下番茄炒出汁...",
            cookingSteps: ["鸡蛋打散备用", "番茄切块去皮", "热锅炒蛋盛起", "炒番茄出汁，加水煮面"],
            nutritionData: NutritionData(protein: 18.2, carbs: 52.8, fat: 8.5, fiber: 4.2, calories: 360)
        ),
        MealSuggestion(
            dishName: "奶香燕麦粥",
            reason: "营养丰富的早餐选择",
            cookingTime: 10,
            difficulty: .easy,
            suitability: "适合减肥",
            ingredients: ["燕麦", "牛奶", "香蕉", "蜂蜜"],
            urgency: .low,
            mealType: .breakfast,
            nutritionHighlights: ["nutrition.highlight.high_fiber".localized, "nutrition.highlight.low_calorie".localized],
            recipePreview: "燕麦加水煮开，倒入牛奶继续煮...",
            cookingSteps: ["燕麦加水煮开", "倒入牛奶继续煮3分钟", "香蕉切片装饰", "最后淋上蜂蜜调味"],
            nutritionData: NutritionData(protein: 12.4, carbs: 38.6, fat: 6.8, fiber: 8.5, calories: 265)
        )
    ]
}