import Foundation
import SwiftData

@MainActor
class IngredientConsumptionService {
    static let shared = IngredientConsumptionService()
    
    private init() {}
    
    func consumeIngredientsForRecipe(_ recipe: RecipeResponse, in context: ModelContext) async throws -> IngredientConsumptionResult {
        var consumedIngredients: [ConsumedIngredient] = []
        var warnings: [String] = []
        var groupsToCheck: Set<FoodGroup> = []
        
        // 检查是否有菜品
        guard !recipe.dishes.isEmpty else {
            return IngredientConsumptionResult(consumedIngredients: [], warnings: ["没有找到菜品"])
        }
        
        // 准备工作
        let allFoodItems = try context.fetch(FetchDescriptor<FoodItem>())
        let ingredientRequirements = parseIngredientRequirements(from: recipe)
        
        // 消耗每种食材
        for requirement in ingredientRequirements {
            let matchingItems = findMatchingFoodItems(for: requirement.name, in: allFoodItems)
            
            if matchingItems.isEmpty {
                warnings.append("未找到食材: \(requirement.name)")
                continue
            }
            
            let (consumedAmount, affectedGroups) = try consumeIngredientWithGroups(
                requirement: requirement,
                matchingItems: matchingItems,
                context: context
            )
            
            if let consumed = consumedAmount {
                consumedIngredients.append(consumed)
            }
            
            // 收集需要检查的组
            groupsToCheck.formUnion(affectedGroups)
        }
        
        // 保存所有食材的更改
        try context.save()
        
        // 批量检查并清理空的食物组
        for group in groupsToCheck {
            if !group.isDeleted && group.items.isEmpty {
                let displayName = group.displayName
                let categoryName = group.category.localizedName
                print("[IngredientConsumptionService] 删除空的食物组: \(displayName) (类别: \(categoryName))")
                context.delete(group)
            }
        }
        
        // 保存组的删除
        if !groupsToCheck.isEmpty {
            try context.save()
        }
        
        // 只有当实际消耗了食材时才执行后续任务
        if !consumedIngredients.isEmpty {
            let ingredientsCopy = consumedIngredients
            let recipeNameCopy = extractRecipeName(from: recipe)
            
            // 执行后续任务
            await HistoryRecordService.shared.recordBatchConsumption(
                consumedIngredients: ingredientsCopy,
                recipeName: recipeNameCopy,
                in: context
            )
            
            // 只检查已消耗且在采购单中的食材
            await checkConsumedIngredientsStock(consumedIngredients: ingredientsCopy, in: context)
        }
        
        return IngredientConsumptionResult(
            consumedIngredients: consumedIngredients,
            warnings: warnings
        )
    }
    
    private func parseIngredientRequirements(from recipe: RecipeResponse) -> [IngredientRequirement] {
        // 从所有菜品中提取食材需求
        var allRequirements: [IngredientRequirement] = []
        
        for dish in recipe.dishes {
            for ingredientGroup in dish.ingredients {
                for recipeIngredient in ingredientGroup.items {
                    if let quantity = Double(recipeIngredient.quantity), quantity > 0 {
                        let requirement = IngredientRequirement(
                            name: recipeIngredient.name,
                            quantity: quantity,
                            unit: recipeIngredient.unit,
                            originalText: "\(recipeIngredient.name) \(recipeIngredient.quantity)\(recipeIngredient.unit)"
                        )
                        allRequirements.append(requirement)
                    }
                }
            }
        }
        
        return allRequirements
    }
    
    
    private func findMatchingFoodItems(for name: String, in allItems: [FoodItem]) -> [FoodItem] {
        let groupingService = FoodGroupingService.shared
        let matches = allItems.filter { item in
            groupingService.shouldGroup(name, item.name)
        }
        
        print("🔍 [IngredientConsumption] 查找食材 '\(name)' 的匹配项:")
        print("   - 总计食材数量: \(allItems.count)")
        print("   - 匹配到的食材: \(matches.map { "\($0.name)(\($0.quantity))" }.joined(separator: ", "))")
        
        return matches
    }
    
    private func consumeIngredientWithGroups(
        requirement: IngredientRequirement,
        matchingItems: [FoodItem],
        context: ModelContext
    ) throws -> (ConsumedIngredient?, Set<FoodGroup>) {
        // 按过期时间排序，先消耗快过期的
        let sortedItems = matchingItems.sorted { item1, item2 in
            guard let date1 = item1.expirationDate, let date2 = item2.expirationDate else {
                return item1.expirationDate != nil
            }
            return date1 < date2
        }
        
        var remainingNeeded = requirement.quantity
        var totalConsumed: Double = 0
        var consumedFromItems: [(FoodItem, Double)] = []
        var affectedGroups: Set<FoodGroup> = []
        
        for item in sortedItems {
            if remainingNeeded <= 0 { break }
            
            let availableQuantity = Double(item.quantity)
            let toConsume = min(remainingNeeded, availableQuantity)
            
            if toConsume > 0 {
                item.quantity -= Int(toConsume)
                totalConsumed += toConsume
                remainingNeeded -= toConsume
                consumedFromItems.append((item, toConsume))
                
                // 如果数量变为0，标记该食材删除并记录其组
                if item.quantity <= 0 {
                    if let group = item.group {
                        affectedGroups.insert(group)
                    }
                    
                    // 清理关系后删除食材
                    item.group = nil
                    context.delete(item)
                }
            }
        }
        
        if totalConsumed > 0 {
            let consumed = ConsumedIngredient(
                name: requirement.name,
                consumedAmount: totalConsumed,
                unit: requirement.unit,
                originalRequirement: requirement.originalText
            )
            return (consumed, affectedGroups)
        }
        
        return (nil, affectedGroups)
    }
    
    private func checkConsumedIngredientsStock(consumedIngredients: [ConsumedIngredient], in context: ModelContext) async {
        do {
            // 获取所有采购单项目
            let shoppingListDescriptor = FetchDescriptor<ShoppingListItem>()
            let shoppingItems = try context.fetch(shoppingListDescriptor)
            
            // 获取当前所有食材
            let foodItemsDescriptor = FetchDescriptor<FoodItem>()
            let allFoodItems = try context.fetch(foodItemsDescriptor)
            
            let groupingService = FoodGroupingService.shared
            var itemsToCheck: [ShoppingListItem] = []
            
            // 只检查已消耗且在采购单中且开启提醒的食材
            for consumedIngredient in consumedIngredients {
                let matchingShoppingItems = shoppingItems.filter { shoppingItem in
                    groupingService.shouldGroup(consumedIngredient.name, shoppingItem.name)
                }
                
                for shoppingItem in matchingShoppingItems {
                    let currentStock = getCurrentStock(for: shoppingItem, in: allFoodItems)
                    
                    print("🎯 [IngredientConsumption] 检查已消耗食材 '\(consumedIngredient.name)' 对应采购单项目 '\(shoppingItem.name)':")
                    print("   - 当前库存: \(currentStock)")
                    print("   - 最小库存: \(shoppingItem.minQuantity)")
                    print("   - 提醒开关: \(shoppingItem.alertEnabled)")
                    print("   - 需要补货: \(currentStock < shoppingItem.minQuantity && shoppingItem.alertEnabled)")
                    
                    if currentStock < shoppingItem.minQuantity && shoppingItem.alertEnabled {
                        itemsToCheck.append(shoppingItem)
                    }
                }
            }
            
            // 如果有需要补货的项目，触发提醒
            if !itemsToCheck.isEmpty {
                print("📝 [IngredientConsumption] 发现 \(itemsToCheck.count) 个需要补货的项目")
                await NotificationManager.shared.scheduleTargetedShoppingReminder(for: itemsToCheck)
            } else {
                print("✅ [IngredientConsumption] 所有已消耗食材库存充足，无需补货提醒")
            }
            
        } catch {
            print("⚠️ [IngredientConsumption] 检查库存失败: \(error)")
        }
    }
    
    private func getCurrentStock(for item: ShoppingListItem, in foodItems: [FoodItem]) -> Int {
        let groupingService = FoodGroupingService.shared
        return foodItems
            .filter { foodItem in
                groupingService.shouldGroup(item.name, foodItem.name)
            }
            .reduce(0) { total, foodItem in
                return total + foodItem.quantity
            }
    }
    
    // MARK: - Helper Methods
    
    /// 从菜谱中提取菜名
    private func extractRecipeName(from recipe: RecipeResponse) -> String {
        // 如果有菜品，使用第一个菜品的名称
        if let firstDish = recipe.dishes.first {
            let dishName = firstDish.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !dishName.isEmpty {
                return dishName
            }
        }
        
        // 如果有多个菜品，生成组合名称
        if recipe.dishes.count > 1 {
            let dishNames = recipe.dishes.prefix(2).map { $0.name }
            return dishNames.joined(separator: " + ")
        }
        
        // 最后的备选方案
        return "AI推荐菜谱"
    }
    
}

// MARK: - Data Models

struct IngredientRequirement {
    let name: String
    let quantity: Double
    let unit: String
    let originalText: String
}

struct ConsumedIngredient {
    let name: String
    let consumedAmount: Double
    let unit: String
    let originalRequirement: String
}

struct IngredientConsumptionResult {
    let consumedIngredients: [ConsumedIngredient]
    let warnings: [String]
}

