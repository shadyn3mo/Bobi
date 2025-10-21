import Foundation
import SwiftData

@Model
final class FoodHistoryRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: RecordType
    var itemName: String
    var quantity: Double
    var unit: String
    var category: FoodCategory
    var recipeName: String? // 如果是消耗，记录食谱名称
    var notes: String? // 额外备注
    
    enum RecordType: String, Codable, CaseIterable {
        case purchase = "purchase"    // 购买记录
        case consumption = "consumption" // 消耗记录
        case expiration = "expiration"   // 过期丢弃记录
        case adjustment = "adjustment"   // 数量调整记录
        case recipeTrial = "recipeTrial" // 菜谱尝试记录
        
        var displayName: String {
            switch self {
            case .purchase: return "history.type.purchase".localized
            case .consumption: return "history.type.consumption".localized
            case .expiration: return "history.type.expiration".localized
            case .adjustment: return "history.type.adjustment".localized
            case .recipeTrial: return "history.type.recipeTrial".localized
            }
        }
        
        var icon: String {
            switch self {
            case .purchase: return "cart.fill"
            case .consumption: return "fork.knife"
            case .expiration: return "trash.fill"
            case .adjustment: return "arrow.up.arrow.down"
            case .recipeTrial: return "lightbulb.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .purchase: return .green
            case .consumption: return .blue
            case .expiration: return .red
            case .adjustment: return .orange
            case .recipeTrial: return .purple
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: RecordType,
        itemName: String,
        quantity: Double,
        unit: String,
        category: FoodCategory,
        recipeName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.itemName = itemName
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.recipeName = recipeName
        self.notes = notes
    }
}

// MARK: - Extensions

extension FoodHistoryRecord {
    
    /// 格式化数量和单位
    var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        
        let quantityString = formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
        return "\(quantityString) \(unit)"
    }
    
    /// 获取显示用的图标
    var displayIcon: String {
        return category.icon
    }
    
    /// 获取记录描述
    var description: String {
        switch type {
        case .purchase:
            return "history.purchase.description".localized
                .replacingOccurrences(of: "{quantity}", with: formattedQuantity)
                .replacingOccurrences(of: "{item}", with: itemName)
        case .consumption:
            let baseDescription = "history.consumption.description".localized
                .replacingOccurrences(of: "{quantity}", with: formattedQuantity)
                .replacingOccurrences(of: "{item}", with: itemName)
            
            if let recipe = recipeName {
                return baseDescription + " " + "history.consumption.recipe".localized
                    .replacingOccurrences(of: "{recipe}", with: recipe)
            }
            return baseDescription
        case .expiration:
            return "history.expiration.description".localized
                .replacingOccurrences(of: "{quantity}", with: formattedQuantity)
                .replacingOccurrences(of: "{item}", with: itemName)
        case .adjustment:
            return "history.adjustment.description".localized
                .replacingOccurrences(of: "{quantity}", with: formattedQuantity)
                .replacingOccurrences(of: "{item}", with: itemName)
        case .recipeTrial:
            return "尝试了菜谱: \(itemName)"
        }
    }
}

import SwiftUI