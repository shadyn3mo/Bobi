import Foundation
import SwiftData

@Model
final class FamilyProfile {
    var id: UUID
    var name: String
    var members: [FamilyMember]
    
    // 使用字符串存储，然后通过计算属性转换
    private var dietaryRestrictionsRaw: String = ""
    private var preferencesRaw: String = ""
    
    var dietaryRestrictions: [DietaryRestriction] {
        get {
            guard !dietaryRestrictionsRaw.isEmpty else { return [] }
            return dietaryRestrictionsRaw.components(separatedBy: ",").compactMap { 
                DietaryRestriction(rawValue: $0.trimmingCharacters(in: .whitespaces))
            }
        }
        set {
            dietaryRestrictionsRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }
    
    var preferences: [String] {
        get {
            guard !preferencesRaw.isEmpty else { return [] }
            return preferencesRaw.components(separatedBy: ",").map { 
                $0.trimmingCharacters(in: .whitespaces)
            }
        }
        set {
            preferencesRaw = newValue.joined(separator: ",")
        }
    }
    
    // 计算家庭总热量需求
    var totalDailyCalories: Double {
        return members.reduce(0) { $0 + $1.dailyCalories }
    }
    
    init(name: String, members: [FamilyMember] = [], dietaryRestrictions: [DietaryRestriction] = [], preferences: [String] = []) {
        self.id = UUID()
        self.name = name
        self.members = members
        self.dietaryRestrictions = dietaryRestrictions
        self.preferences = preferences
    }
}

@Model
final class FamilyMember: Identifiable {
    var id: UUID
    var name: String
    var age: Int
    var monthsForBaby: Int = 0 // 婴儿月份 (仅当 age = 0 时有效)
    var gender: Gender
    var heightCm: Double = 170.0 // 身高（厘米）
    var weightKg: Double = 70.0 // 体重（公斤）
    var activityLevel: ActivityLevel
    
    // 使用字符串存储饮食限制
    private var dietaryRestrictionsRaw: String = ""
    
    // 使用字符串存储自定义过敏源
    private var customAllergiesRaw: String = ""
    
    var dietaryRestrictions: [DietaryRestriction] {
        get {
            guard !dietaryRestrictionsRaw.isEmpty else { return [] }
            return dietaryRestrictionsRaw.components(separatedBy: ",").compactMap { 
                DietaryRestriction(rawValue: $0.trimmingCharacters(in: .whitespaces))
            }
        }
        set {
            dietaryRestrictionsRaw = newValue.map { $0.rawValue }.joined(separator: ",")
        }
    }
    
    var customAllergies: [String] {
        get {
            guard !customAllergiesRaw.isEmpty else { return [] }
            return customAllergiesRaw.components(separatedBy: ",").map { 
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
        }
        set {
            customAllergiesRaw = newValue.joined(separator: ",")
        }
    }
    
    // 组合所有过敏信息的便利属性
    var allAllergyInfo: [String] {
        let predefinedAllergies = dietaryRestrictions
            .filter { $0.category == .allergy }
            .map { $0.localizedName }
        
        return predefinedAllergies + customAllergies
    }
    
    var dailyCalorieTarget: Double {
        // 使用 Harris-Benedict 公式计算BMR（基础代谢率）
        let bmr: Double
        switch gender {
        case .male:
            // 男性: BMR = (13.7516 × weight in kg) + (5.0033 × height in cm) – (6.755 × age in years) + 66.473
            bmr = (13.7516 * weightKg) + (5.0033 * heightCm) - (6.755 * Double(age)) + 66.473
        case .female:
            // 女性: BMR = (9.5634 × weight in kg) + (1.8496 × height in cm) – (4.6756 × age in years) + 655.0955
            bmr = (9.5634 * weightKg) + (1.8496 * heightCm) - (4.6756 * Double(age)) + 655.0955
        }
        
        // TDEE = BMR × 活动系数
        return bmr * activityLevel.multiplier
    }
    
    // 兼容性属性
    var dailyCalories: Double {
        return dailyCalorieTarget
    }
    
    var ageCategory: AgeCategory {
        switch age {
        case 0...2: return .baby
        case 3...12: return .child
        case 13...35: return .youth
        case 36...64: return .adult
        case 65...: return .senior
        default: return .senior
        }
    }
    
    var babyFoodStage: BabyFoodStage? {
        guard age == 0, monthsForBaby > 0 else { return nil }
        switch monthsForBaby {
        case 6...8: return .stage1
        case 9...12: return .stage2
        default: return nil
        }
    }
    
    init(name: String, age: Int, gender: Gender, monthsForBaby: Int = 0, heightCm: Double = 170.0, weightKg: Double = 70.0, activityLevel: ActivityLevel = .moderate, dietaryRestrictions: [DietaryRestriction] = [], customAllergies: [String] = []) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.monthsForBaby = monthsForBaby
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.activityLevel = activityLevel
        self.dietaryRestrictions = dietaryRestrictions
        self.customAllergies = customAllergies
    }
}

enum BabyFoodStage: String, CaseIterable, Codable {
    case stage1 = "Stage1" // 6-8 months: 辅食泥
    case stage2 = "Stage2" // 9-12 months: 颗粒/块状辅食
}

enum Gender: String, CaseIterable, Codable {
    case male = "Male"
    case female = "Female"
}

enum AgeCategory: String, CaseIterable, Codable {
    case baby = "Baby"           // 0-2
    case child = "Child"         // 3-12
    case youth = "Youth"         // 13-35
    case adult = "Adult"         // 36-64
    case senior = "Senior"       // 65+
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "Sedentary"
    case light = "Light"
    case moderate = "Moderate"
    case active = "Active"
    case veryActive = "Very Active"
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }
}

enum DietaryRestriction: String, CaseIterable, Codable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case nutFree = "Nut-Free"
    case lowSodium = "Low Sodium"
    case diabetic = "Diabetic"
    case kosher = "Kosher"
    case halal = "Halal"
    
    // 过敏相关
    case shellFishAllergy = "Shellfish Allergy"
    case eggAllergy = "Egg Allergy"
    case fishAllergy = "Fish Allergy"
    case soyAllergy = "Soy Allergy"
    case wheatAllergy = "Wheat Allergy"
    case sesameAllergy = "Sesame Allergy"
    case sulfiteAllergy = "Sulfite Allergy"
    case mushroomAllergy = "Mushroom Allergy"
    
    var category: DietaryRestrictionCategory {
        switch self {
        case .vegetarian, .vegan:
            return .lifestyle
        case .glutenFree, .dairyFree, .nutFree:
            return .dietary
        case .lowSodium, .diabetic:
            return .health
        case .kosher, .halal:
            return .religious
        case .shellFishAllergy, .eggAllergy, .fishAllergy, .soyAllergy, .wheatAllergy, .sesameAllergy, .sulfiteAllergy, .mushroomAllergy:
            return .allergy
        }
    }
}

enum DietaryRestrictionCategory: String, CaseIterable {
    case lifestyle = "Lifestyle"
    case dietary = "Dietary"
    case health = "Health"
    case religious = "Religious"
    case allergy = "Allergy"
    
    var localizedName: String {
        switch self {
        case .lifestyle: return "family.dietary.category.lifestyle".localized
        case .dietary: return "family.dietary.category.dietary".localized
        case .health: return "family.dietary.category.health".localized
        case .religious: return "family.dietary.category.religious".localized
        case .allergy: return "family.dietary.category.allergy".localized
        }
    }
    
    var icon: String {
        switch self {
        case .lifestyle: return "leaf.circle.fill"
        case .dietary: return "fork.knife.circle.fill"
        case .health: return "heart.circle.fill"
        case .religious: return "star.circle.fill"
        case .allergy: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .lifestyle: return "green"
        case .dietary: return "blue"
        case .health: return "red"
        case .religious: return "purple"
        case .allergy: return "orange"
        }
    }
}