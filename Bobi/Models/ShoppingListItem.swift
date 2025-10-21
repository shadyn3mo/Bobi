import Foundation
import SwiftData

@Model
final class ShoppingListItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: FoodCategory
    var unit: String
    var minQuantity: Int
    var alertEnabled: Bool
    var createdDate: Date
    var estimatedPrice: Double?
    
    // 计算属性：是否紧急
    var isUrgent: Bool {
        // 如果设置了警报且最小数量较高，则认为是紧急的
        return alertEnabled && minQuantity > 0
    }
    
    // MARK: - Formatted Display Properties (like FoodItem)
    var formattedQuantityWithUnit: String {
        return UnitDisplayHelper.formatQuantityWithUnit(Double(minQuantity), unit: unit)
    }
    
    init(name: String, category: FoodCategory, unit: String, minQuantity: Int, alertEnabled: Bool = true, estimatedPrice: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.unit = unit
        self.minQuantity = minQuantity
        self.alertEnabled = alertEnabled
        self.createdDate = Date()
        self.estimatedPrice = estimatedPrice
    }
}