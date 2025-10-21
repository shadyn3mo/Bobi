import Foundation
import SwiftData

@Model
final class FoodItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var barcode: String?
    var purchaseDate: Date
    var expirationDate: Date?
    var category: FoodCategory
    var quantity: Int
    var unit: String
    var nutritionInfo: NutritionInfo?
    var imageData: Data?
    var stockAlertEnabled: Bool
    var specificEmoji: String?
    var storageLocation: StorageLocation?
    
    // 分组关系
    @Relationship var group: FoodGroup?
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expireDay = calendar.startOfDay(for: expirationDate)
        return calendar.dateComponents([.day], from: today, to: expireDay).day
    }
    
    var displayIcon: String {
        return specificEmoji ?? category.icon
    }
    
    var safeStorageLocation: StorageLocation {
        if let location = storageLocation {
            return location
        } else {
            // 如果存储位置为空，使用智能推荐但不在计算属性中修改状态
            return StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: name, category: category)
        }
    }
    
    // 添加一个方法来更新存储位置
    @MainActor
    func updateStorageLocationIfNeeded() {
        if storageLocation == nil {
            let recommended = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: name, category: category)
            storageLocation = recommended
        }
    }
    
    static var defaultUnit: String {
        return "个" // 内部统一使用"个"作为默认单位
    }
    
    static var defaultDisplayUnit: String {
        let currentLanguage = LocalizationManager.shared.selectedLanguage
        return currentLanguage == "en" ? "pcs" : "个"
    }
    
    // MARK: - 智能单位显示
    var formattedQuantityWithUnit: String {
        return UnitDisplayHelper.formatQuantityWithUnit(Double(quantity), unit: unit)
    }
    
    var needsUnitGuidance: Bool {
        return UnitDisplayHelper.needsUnitGuidance(name: name, unit: unit, quantity: Double(quantity))
    }
    
    var suggestedUnits: [String] {
        return UnitDisplayHelper.getSuggestedUnits(for: name)
    }
    
    init(name: String, barcode: String? = nil, purchaseDate: Date = Date(), expirationDate: Date? = nil, category: FoodCategory = .other, quantity: Int = 1, unit: String = FoodItem.defaultUnit, stockAlertEnabled: Bool = false, specificEmoji: String? = nil, storageLocation: StorageLocation? = nil) {
        self.id = UUID()
        self.name = name
        self.barcode = barcode
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.stockAlertEnabled = stockAlertEnabled
        self.specificEmoji = specificEmoji
        
        // 设置存储位置，如果没有提供则使用智能推荐
        if let providedLocation = storageLocation {
            self.storageLocation = providedLocation
        } else {
            // 使用推荐引擎
            self.storageLocation = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: name, category: category)
        }
    }
}

enum FoodCategory: String, CaseIterable, Codable {
    case dairy = "Dairy"
    case eggs = "Eggs"
    case meat = "Meat"
    case seafood = "Seafood"
    case vegetables = "Vegetables"
    case fruits = "Fruits"
    case grains = "Grains"
    case beverages = "Beverages"
    case condiments = "Condiments"
    case frozen = "Frozen"
    case canned = "Canned"
    case snacks = "Snacks"
    case other = "Other"
    
    // Legacy case mappings for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "Vegetables", "vegetables": // Handle legacy "Vegetables" values
            self = .vegetables
        case "Fruits", "fruits": // Handle legacy "Fruits" values
            self = .fruits
        case "Produce", "produce": // Handle legacy "Produce" values by defaulting to vegetables
            self = .vegetables
        default:
            if let category = FoodCategory(rawValue: rawValue) {
                self = category
            } else {
                print("[FoodCategory] Unknown category '\(rawValue)', defaulting to .other")
                self = .other
            }
        }
    }
    
    var localizedName: String {
        switch self {
        case .dairy: return "category.dairy".localized
        case .eggs: return "category.eggs".localized
        case .meat: return "category.meat".localized
        case .seafood: return "category.seafood".localized
        case .vegetables: return "category.vegetables".localized
        case .fruits: return "category.fruits".localized
        case .grains: return "category.grains".localized
        case .beverages: return "category.beverages".localized
        case .condiments: return "category.condiments".localized
        case .frozen: return "category.frozen".localized
        case .canned: return "category.canned".localized
        case .snacks: return "category.snacks".localized
        case .other: return "category.other".localized
        }
    }
    
    var icon: String {
        switch self {
        case .dairy: return "🥛"
        case .eggs: return "🥚"
        case .meat: return "🥩"
        case .seafood: return "🐟"
        case .vegetables: return "🥬"
        case .fruits: return "🍎"
        case .grains: return "🌾"
        case .beverages: return "🥤"
        case .condiments: return "🧂"
        case .frozen: return "🧊"
        case .canned: return "🥫"
        case .snacks: return "🍿"
        case .other: return "📦"
        }
    }
}
