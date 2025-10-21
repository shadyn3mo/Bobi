import Foundation
import SwiftData

@MainActor
class HistoryRecordService: ObservableObject {
    static let shared = HistoryRecordService()
    
    private init() {}
    
    // MARK: - Record Creation Methods
    
    /// 记录食材购买（支持延迟保存）
    func recordPurchase(
        itemName: String,
        quantity: Double,
        unit: String,
        category: FoodCategory,
        purchaseDate: Date = Date(),
        in context: ModelContext,
        notes: String? = nil,
        deferredSave: Bool = false
    ) async {
        let record = FoodHistoryRecord(
            date: purchaseDate,
            type: .purchase,
            itemName: itemName,
            quantity: quantity,
            unit: unit,
            category: category,
            notes: notes
        )
        
        context.insert(record)
        
        // 只有在不是延迟保存时才立即保存
        if !deferredSave {
            do {
                try context.save()
                print("[HistoryRecordService] 记录购买: \(itemName) \(quantity)\(unit)")
            } catch {
                print("[HistoryRecordService] 保存购买记录失败: \(error)")
            }
        }
    }
    
    /// 记录食材消耗
    func recordConsumption(
        itemName: String,
        quantity: Double,
        unit: String,
        category: FoodCategory,
        recipeName: String?,
        in context: ModelContext,
        notes: String? = nil
    ) async {
        let record = FoodHistoryRecord(
            type: .consumption,
            itemName: itemName,
            quantity: quantity,
            unit: unit,
            category: category,
            recipeName: recipeName,
            notes: notes
        )
        
        context.insert(record)
        
        do {
            try context.save()
            print("[HistoryRecordService] 记录消耗: \(itemName) \(quantity)\(unit) for \(recipeName ?? "unknown recipe")")
        } catch {
            print("[HistoryRecordService] 保存消耗记录失败: \(error)")
        }
    }
    
    /// 记录食材过期
    func recordExpiration(
        itemName: String,
        quantity: Double,
        unit: String,
        category: FoodCategory,
        in context: ModelContext,
        notes: String? = nil
    ) async {
        let record = FoodHistoryRecord(
            type: .expiration,
            itemName: itemName,
            quantity: quantity,
            unit: unit,
            category: category,
            notes: notes
        )
        
        context.insert(record)
        
        do {
            try context.save()
            print("[HistoryRecordService] 记录过期: \(itemName) \(quantity)\(unit)")
        } catch {
            print("[HistoryRecordService] 保存过期记录失败: \(error)")
        }
    }
    
    /// 记录食材数量调整
    func recordQuantityAdjustment(
        itemName: String,
        oldQuantity: Double,
        newQuantity: Double,
        unit: String,
        category: FoodCategory,
        in context: ModelContext,
        notes: String? = nil
    ) async {
        let adjustmentAmount = newQuantity - oldQuantity
        let adjustmentNotes = notes ?? "quantity.adjustment.from.to".localized
            .replacingOccurrences(of: "{oldQuantity}", with: "\(oldQuantity)")
            .replacingOccurrences(of: "{newQuantity}", with: "\(newQuantity)")
        
        let record = FoodHistoryRecord(
            type: .adjustment,
            itemName: itemName,
            quantity: adjustmentAmount,
            unit: unit,
            category: category,
            notes: adjustmentNotes
        )
        
        context.insert(record)
        
        do {
            try context.save()
            print("[HistoryRecordService] 记录数量调整: \(itemName) \(adjustmentAmount > 0 ? "+" : "")\(adjustmentAmount)\(unit)")
        } catch {
            print("[HistoryRecordService] 保存数量调整记录失败: \(error)")
        }
    }
    
    /// 批量记录过期食材（优化版本）
    func recordBatchExpiration(
        items: [FoodItem],
        in context: ModelContext
    ) async {
        // 批量创建所有记录
        let records = items.map { item in
            FoodHistoryRecord(
                type: .expiration,
                itemName: item.name,
                quantity: Double(item.quantity),
                unit: item.unit,
                category: item.category,
                notes: "expired.on.date".localized
                    .replacingOccurrences(of: "{date}", with: item.expirationDate?.formatted(.dateTime.month().day()) ?? "")
            )
        }
        
        // 批量插入到context
        for record in records {
            context.insert(record)
        }
        
        // 单次保存所有记录
        do {
            try context.save()
            print("[HistoryRecordService] 批量记录过期: \(items.count) 个食材")
        } catch {
            print("[HistoryRecordService] 批量保存过期记录失败: \(error)")
        }
    }
    
    /// 更新购买记录的日期
    func updatePurchaseRecordDate(
        itemName: String,
        oldPurchaseDate: Date,
        newPurchaseDate: Date,
        in context: ModelContext
    ) async {
        do {
            let descriptor = FetchDescriptor<FoodHistoryRecord>(
                predicate: #Predicate { record in
                    record.itemName == itemName && record.type.rawValue == "purchase"
                }
            )
            
            let records = try context.fetch(descriptor)
            
            // 找到最接近旧购买日期的记录
            let calendar = Calendar.current
            if let matchingRecord = records.min(by: { record1, record2 in
                let diff1 = abs(calendar.dateComponents([.day], from: record1.date, to: oldPurchaseDate).day ?? Int.max)
                let diff2 = abs(calendar.dateComponents([.day], from: record2.date, to: oldPurchaseDate).day ?? Int.max)
                return diff1 < diff2
            }) {
                matchingRecord.date = newPurchaseDate
                
                try context.save()
                print("[HistoryRecordService] 更新购买日期: \(itemName) 从 \(oldPurchaseDate) 改为 \(newPurchaseDate)")
            }
        } catch {
            print("[HistoryRecordService] 更新购买日期失败: \(error)")
        }
    }
    
    // MARK: - Batch Recording Methods
    
    /// 批量记录购买（优化版本）
    func recordBatchPurchase(
        items: [ParsedFoodItem],
        in context: ModelContext
    ) async {
        // 批量创建所有记录
        let records = items.map { item in
            FoodHistoryRecord(
                date: item.purchaseDate,
                type: .purchase,
                itemName: item.name,
                quantity: Double(item.quantity),
                unit: item.unit,
                category: item.category,
                notes: nil
            )
        }
        
        // 批量插入到context
        for record in records {
            context.insert(record)
        }
        
        // 单次保存所有记录
        do {
            try context.save()
            print("[HistoryRecordService] 批量记录购买: \(items.count) 个食材")
        } catch {
            print("[HistoryRecordService] 批量保存购买记录失败: \(error)")
        }
    }
    
    /// 批量记录消耗（优化版本）
    func recordBatchConsumption(
        consumedIngredients: [ConsumedIngredient],
        recipeName: String?,
        in context: ModelContext
    ) async {
        // 预先查询所有需要的分类信息，避免多次查询
        let categoryMap = await batchFindCategories(
            for: consumedIngredients.map { $0.name },
            in: context
        )
        
        // 批量创建记录
        let records = consumedIngredients.map { ingredient in
            FoodHistoryRecord(
                type: .consumption,
                itemName: ingredient.name,
                quantity: ingredient.consumedAmount,
                unit: ingredient.unit,
                category: categoryMap[ingredient.name] ?? .other,
                recipeName: recipeName,
                notes: nil
            )
        }
        
        // 批量插入和保存
        for record in records {
            context.insert(record)
        }
        
        do {
            try context.save()
            print("[HistoryRecordService] 批量记录消耗: \(consumedIngredients.count) 个食材用于 \(recipeName ?? "unknown recipe")")
        } catch {
            print("[HistoryRecordService] 批量保存消耗记录失败: \(error)")
        }
    }
    
    
    // MARK: - Helper Methods
    
    /// 批量查找食材分类，避免重复查询
    private func batchFindCategories(
        for itemNames: [String],
        in context: ModelContext
    ) async -> [String: FoodCategory] {
        do {
            let descriptor = FetchDescriptor<FoodItem>()
            let allItems = try context.fetch(descriptor)
            
            var categoryMap: [String: FoodCategory] = [:]
            
            for itemName in itemNames {
                // 查找最匹配的食材
                if let matchingItem = allItems.first(where: { $0.name.contains(itemName) || itemName.contains($0.name) }) {
                    categoryMap[itemName] = matchingItem.category
                } else {
                    categoryMap[itemName] = .other
                }
            }
            
            return categoryMap
        } catch {
            print("[HistoryRecordService] 批量查找食材分类失败: \(error)")
            return itemNames.reduce(into: [:]) { result, name in
                result[name] = .other
            }
        }
    }
    
    /// 查找食材的分类
    private func findCategoryForItem(_ itemName: String, in context: ModelContext) async -> FoodCategory {
        do {
            let descriptor = FetchDescriptor<FoodItem>(
                predicate: #Predicate<FoodItem> { item in
                    item.name.contains(itemName)
                }
            )
            
            let items = try context.fetch(descriptor)
            return items.first?.category ?? .other
        } catch {
            print("[HistoryRecordService] 查找食材分类失败: \(error)")
            return .other
        }
    }
    
    /// 手动触发保存（用于延迟保存场景）
    func saveContext(_ context: ModelContext) async {
        do {
            try context.save()
            print("[HistoryRecordService] 手动保存成功")
        } catch {
            print("[HistoryRecordService] 手动保存失败: \(error)")
        }
    }
    
    // MARK: - Cleanup Methods
    
    /// 清理所有历史记录
    func clearAllRecords(in context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<FoodHistoryRecord>()
            let allRecords = try context.fetch(descriptor)
            
            for record in allRecords {
                context.delete(record)
            }
            
            try context.save()
            print("[HistoryRecordService] 已清理所有历史记录")
        } catch {
            print("[HistoryRecordService] 清理历史记录失败: \(error)")
        }
    }
    
    /// 清理指定日期前的记录
    func clearRecordsBefore(date: Date, in context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<FoodHistoryRecord>(
                predicate: #Predicate { record in
                    record.date < date
                }
            )
            
            let oldRecords = try context.fetch(descriptor)
            
            for record in oldRecords {
                context.delete(record)
            }
            
            try context.save()
            print("[HistoryRecordService] 已清理 \(date) 之前的 \(oldRecords.count) 条记录")
        } catch {
            print("[HistoryRecordService] 清理历史记录失败: \(error)")
        }
    }
    
    /// 自动清理超过30天的记录
    func performAutoCleanup(in context: ModelContext) async {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        await clearRecordsBefore(date: thirtyDaysAgo, in: context)
    }
    
    // MARK: - Query Methods
    
    /// 获取指定日期范围的记录
    func getRecords(
        from startDate: Date,
        to endDate: Date,
        type: FoodHistoryRecord.RecordType? = nil,
        in context: ModelContext
    ) async -> [FoodHistoryRecord] {
        do {
            let descriptor: FetchDescriptor<FoodHistoryRecord>
            
            if let recordType = type {
                descriptor = FetchDescriptor<FoodHistoryRecord>(
                    predicate: #Predicate { record in
                        record.date >= startDate && record.date <= endDate && record.type.rawValue == recordType.rawValue
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<FoodHistoryRecord>(
                    predicate: #Predicate { record in
                        record.date >= startDate && record.date <= endDate
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
            
            return try context.fetch(descriptor)
        } catch {
            print("[HistoryRecordService] 查询历史记录失败: \(error)")
            return []
        }
    }
    
    /// 获取统计信息
    func getStatistics(
        from startDate: Date,
        to endDate: Date,
        in context: ModelContext
    ) async -> HistoryStatistics {
        let records = await getRecords(from: startDate, to: endDate, in: context)
        
        let purchaseRecords = records.filter { $0.type == .purchase }
        let consumptionRecords = records.filter { $0.type == .consumption }
        let expirationRecords = records.filter { $0.type == .expiration }
        let adjustmentRecords = records.filter { $0.type == .adjustment }
        
        // 计算实际制作的菜品数（consumption类型且有recipeName的记录）
        let uniqueRecipesCount = Set(consumptionRecords.compactMap { $0.recipeName }).count
        
        // 计算实际制作次数（按菜谱名和时间分组）
        let totalCookingInstances = calculateCookingInstances(from: consumptionRecords)
        
        return HistoryStatistics(
            totalPurchaseCount: purchaseRecords.count,
            totalConsumptionCount: totalCookingInstances,
            totalExpirationCount: expirationRecords.count,
            totalAdjustmentCount: adjustmentRecords.count,
            uniqueRecipesCount: uniqueRecipesCount,
            topCategories: getTopCategories(from: records),
            recentActivity: Array(records.prefix(10))
        )
    }
    
    /// 计算实际制作次数（按菜谱名和时间分组）
    private func calculateCookingInstances(from consumptionRecords: [FoodHistoryRecord]) -> Int {
        // 按菜谱名分组
        let recipeGroups = Dictionary(grouping: consumptionRecords.filter { $0.recipeName != nil }) { record in
            record.recipeName!
        }
        
        var totalInstances = 0
        
        for (_, records) in recipeGroups {
            // 按时间排序
            let sortedRecords = records.sorted { $0.date < $1.date }
            
            // 计算制作实例：如果相邻记录的时间差超过5分钟，认为是不同的制作实例
            var instances = 1
            for i in 1..<sortedRecords.count {
                let timeDifference = sortedRecords[i].date.timeIntervalSince(sortedRecords[i-1].date)
                if timeDifference > 300 { // 5分钟 = 300秒
                    instances += 1
                }
            }
            totalInstances += instances
        }
        
        // 加上没有菜谱名的消耗记录（每个都算作一次制作）
        let nonRecipeConsumption = consumptionRecords.filter { $0.recipeName == nil }.count
        totalInstances += nonRecipeConsumption
        
        return totalInstances
    }
    
    private func getTopCategories(from records: [FoodHistoryRecord]) -> [CategoryStatistic] {
        let categoryGroups = Dictionary(grouping: records, by: { $0.category })
        
        return categoryGroups.map { category, records in
            CategoryStatistic(
                category: category,
                count: records.count,
                totalQuantity: records.reduce(0) { $0 + $1.quantity }
            )
        }
        .sorted { $0.count > $1.count }
        .prefix(5)
        .map { $0 }
    }
}

// MARK: - Data Models

struct HistoryStatistics {
    let totalPurchaseCount: Int
    let totalConsumptionCount: Int
    let totalExpirationCount: Int
    let totalAdjustmentCount: Int
    let uniqueRecipesCount: Int
    let topCategories: [CategoryStatistic]
    let recentActivity: [FoodHistoryRecord]
}

struct CategoryStatistic {
    let category: FoodCategory
    let count: Int
    let totalQuantity: Double
}