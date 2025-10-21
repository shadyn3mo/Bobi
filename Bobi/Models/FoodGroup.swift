import Foundation
import SwiftData

@Model
final class FoodGroup: Identifiable {
    @Attribute(.unique) var id: UUID
    var baseName: String  // 基础食物名称（如"苹果"）
    var displayName: String  // 显示名称
    var category: FoodCategory
    var createdDate: Date
    var lastUpdated: Date
    var customEmoji: String?  // 用户自定义的emoji
    
    // 关联的食物子项
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.group)
    var items: [FoodItem] = []
    
    // 计算属性
    var totalQuantity: Int {
        // 检查是否所有项目使用相同单位
        let uniqueUnits = Set(items.map { $0.unit })
        
        if uniqueUnits.count <= 1 {
            // 所有项目使用相同单位或没有项目，直接累加数量
            return items.reduce(0) { total, item in
                total + item.quantity
            }
        } else {
            // 不同单位，尝试转换为统一单位
            let convertedTotal = items.reduce(0.0) { total, item in
                let unitType = UnitDisplayHelper.getUnitType(item.unit)
                if unitType == .volume {
                    // 体积单位转换为毫升
                    return total + convertVolumeToML(quantity: Double(item.quantity), unit: item.unit)
                } else if unitType == .weight {
                    // 重量单位转换为克
                    return total + convertWeightToGrams(quantity: Double(item.quantity), unit: item.unit)
                } else {
                    // 其他单位按件数计算
                    return total + Double(item.quantity)
                }
            }
            return Int(convertedTotal)
        }
    }
    
    // MARK: - 单位转换辅助方法
    private func convertVolumeToML(quantity: Double, unit: String) -> Double {
        let normalizedUnit = unit.lowercased()
        switch normalizedUnit {
        case "l", "L", "升":
            return quantity * 1000
        case "gallon", "加仑":
            return quantity * 3785
        case "cup", "杯":
            return quantity * 240
        default:
            return quantity // 默认已经是毫升
        }
    }
    
    private func convertWeightToGrams(quantity: Double, unit: String) -> Double {
        let normalizedUnit = unit.lowercased()
        switch normalizedUnit {
        case "kg", "千克", "公斤":
            return quantity * 1000
        case "lb", "磅":
            return quantity * 453.592
        case "斤":
            return quantity * 500
        case "两":
            return quantity * 50
        default:
            return quantity // 默认已经是克
        }
    }
    
    var primaryUnit: String {
        // 找到最常用的单位
        let unitCounts = Dictionary(grouping: items, by: { $0.unit }).mapValues { $0.count }
        return unitCounts.max(by: { $0.value < $1.value })?.key ?? FoodItem.defaultUnit
    }
    
    var displayUnit: String {
        let currentLanguage = LocalizationManager.shared.selectedLanguage
        
        if primaryUnit == FoodItem.defaultUnit {
            return currentLanguage == "en" ? "pcs" : "个"
        } else {
            return primaryUnit
        }
    }
    
    // MARK: - 智能单位显示
    var formattedTotalQuantityWithUnit: String {
        return UnitDisplayHelper.formatQuantityWithUnit(Double(totalQuantity), unit: primaryUnit)
    }
    
    var hasItemsNeedingUnitGuidance: Bool {
        return items.contains { $0.needsUnitGuidance }
    }
    
    var earliestExpirationDate: Date? {
        return items.compactMap { $0.expirationDate }.min()
    }
    
    var earliestPurchaseDate: Date {
        return items.map { $0.purchaseDate }.min() ?? Date()
    }
    
    var isExpired: Bool {
        guard let expirationDate = earliestExpirationDate else { return false }
        return Date() > expirationDate
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = earliestExpirationDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expireDay = calendar.startOfDay(for: expirationDate)
        return calendar.dateComponents([.day], from: today, to: expireDay).day
    }
    
    var displayIcon: String {
        // 优先级：自定义emoji > 第一个有特定emoji的食物 > 分类icon
        if let customEmoji = customEmoji {
            return customEmoji
        }
        return items.first(where: { $0.specificEmoji != nil })?.specificEmoji ?? category.icon
    }
    
    init(baseName: String, displayName: String, category: FoodCategory) {
        self.id = UUID()
        self.baseName = baseName
        self.displayName = displayName
        self.category = category
        self.createdDate = Date()
        self.lastUpdated = Date()
    }
    
    /// 添加食物项目到组中
    func addItem(_ item: FoodItem) {
        // 检查是否已经存在，避免重复添加
        if !items.contains(where: { $0.id == item.id }) {
            items.append(item)
            lastUpdated = Date()
            
            // 更新显示名称（可能需要重新生成）
            updateDisplayName()
        }
    }
    
    /// 从组中移除食物项目
    func removeItem(_ item: FoodItem) {
        items.removeAll { $0.id == item.id }
        lastUpdated = Date()
        
        // 如果组为空，则应该删除组
        if items.isEmpty {
            // 这里需要在调用方处理组的删除
        } else {
            updateDisplayName()
        }
    }
    
    /// 更新显示名称
    private func updateDisplayName() {
        // 重新生成最合适的显示名称
        displayName = FoodGroupingService.shared.generateGroupDisplayName(for: items)
    }
    
    /// 检查是否可以将某个食物项目加入此组
    func canAccept(_ foodItem: FoodItem) -> Bool {
        // 检查基础名称是否匹配
        let itemBaseName = FoodGroupingService.shared.getBaseFoodName(foodItem.name)
        return itemBaseName.lowercased() == baseName.lowercased() ||
               FoodGroupingService.shared.shouldGroup(baseName, foodItem.name)
    }
}

// MARK: - FoodGroup 管理器
class FoodGroupManager {
    static let shared = FoodGroupManager()
    
    private init() {}
    
    /// 为新食物项目找到或创建合适的组
    func findOrCreateGroup(for foodItem: FoodItem, in context: ModelContext) -> FoodGroup {
        let baseName = FoodGroupingService.shared.getBaseFoodName(foodItem.name)
        
        // 查找现有的组 - 使用精确匹配或应该分组逻辑
        let descriptor = FetchDescriptor<FoodGroup>(
            predicate: #Predicate<FoodGroup> { group in
                group.baseName == baseName
            }
        )
        
        if let existingGroups = try? context.fetch(descriptor) {
            // 找到可以接受这个食物的组
            for group in existingGroups {
                if group.canAccept(foodItem) {
                    return group
                }
            }
        }
        
        // 如果没有找到合适的组，创建新组
        let displayName = FoodGroupingService.shared.generateGroupDisplayName(for: [foodItem])
        let newGroup = FoodGroup(baseName: baseName, displayName: displayName, category: foodItem.category)
        context.insert(newGroup)
        
        print("[FoodGroupManager] 创建新组: baseName='\(baseName)', displayName='\(displayName)', category=\(foodItem.category), 原食物名='\(foodItem.name)'")
        
        return newGroup
    }
    
    
    /// 获取所有食物组，按过期时间排序
    func getAllGroups(from context: ModelContext) throws -> [FoodGroup] {
        let descriptor = FetchDescriptor<FoodGroup>(
            sortBy: [SortDescriptor(\FoodGroup.lastUpdated, order: .reverse)]
        )
        
        return try context.fetch(descriptor).sorted { group1, group2 in
            // 优先按过期时间排序
            guard let exp1 = group1.earliestExpirationDate,
                  let exp2 = group2.earliestExpirationDate else {
                return group1.earliestExpirationDate != nil
            }
            return exp1 < exp2
        }
    }
}