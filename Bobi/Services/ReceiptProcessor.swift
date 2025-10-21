import Foundation
import SwiftData

class ReceiptProcessor {
    static let shared = ReceiptProcessor()
    
    private init() {}
    
    @MainActor
    func addItemsFromReceipt(_ receipt: ParsedReceipt, modelContext: ModelContext) async throws -> Int {
        guard !receipt.items.isEmpty else {
            throw ReceiptProcessorError.invalidReceiptData
        }
        
        var addedItems: [FoodItem] = []
        var failedItems: [String] = []
        
        for receiptItem in receipt.items {
            do {
                let foodItem = try await createFoodItem(
                    from: receiptItem,
                    purchaseDate: receipt.purchaseDate
                )
                
                // 自动归类到合适的组
                let group = FoodGroupManager.shared.findOrCreateGroup(for: foodItem, in: modelContext)
                foodItem.group = group
                group.addItem(foodItem)
                
                modelContext.insert(foodItem)
                addedItems.append(foodItem)
            } catch {
                failedItems.append(receiptItem.name)
                continue
            }
        }
        
        guard !addedItems.isEmpty else {
            throw ReceiptProcessorError.failedToCreateFoodItem
        }
        
        do {
            try modelContext.save()
            
            // 记录购买历史
            let parsedItems = addedItems.map { foodItem in
                ParsedFoodItem(
                    name: foodItem.name,
                    quantity: foodItem.quantity,
                    unit: foodItem.unit,
                    category: foodItem.category,
                    purchaseDate: foodItem.purchaseDate,
                    estimatedExpirationDate: foodItem.expirationDate,
                    specificEmoji: foodItem.specificEmoji,
                    recommendedStorageLocation: foodItem.safeStorageLocation,
                    storageLocation: foodItem.safeStorageLocation,
                    imageData: foodItem.imageData
                )
            }
            
            Task {
                await HistoryRecordService.shared.recordBatchPurchase(
                    items: parsedItems,
                    in: modelContext
                )
            }
            
            // 收据扫描添加食品后刷新通知
            Task { @MainActor in
                NotificationManager.shared.refreshNotifications()
            }
        } catch {
            throw error
        }
        
        NotificationCenter.default.post(
            name: .receiptItemsAdded,
            object: nil,
            userInfo: ["items": addedItems, "receipt": receipt, "failedItems": failedItems]
        )
        
        return addedItems.count
    }
    
    private func createFoodItem(
        from receiptItem: ParsedReceiptItem,
        purchaseDate: Date
    ) async throws -> FoodItem {
        
        // 使用智能分类服务自动分类
        let classifiedCategory = await classifyFoodItem(receiptItem.name, aiCategory: receiptItem.category)
        let storageLocation = suggestStorageLocation(for: classifiedCategory)
        let (quantity, unit) = parseQuantityAndUnit(receiptItem.quantity)
        let expirationDate = calculateExpirationDate(
            from: purchaseDate,
            category: classifiedCategory,
            storageLocation: storageLocation
        )
        
        let foodItem = FoodItem(
            name: receiptItem.name,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            category: classifiedCategory,
            quantity: Int(quantity),
            unit: unit,
            storageLocation: storageLocation
        )
        
        return foodItem
    }
    
    private func classifyFoodItem(_ name: String, aiCategory: String?) async -> FoodCategory {
        // 首先尝试使用AI提供的分类
        if let aiCategory = aiCategory {
            let mappedCategory = mapCategory(aiCategory)
            if mappedCategory != .other {
                return mappedCategory
            }
        }
        
        // 如果AI分类无效，使用本地分类服务
        if #available(iOS 17.0, *) {
            let (category, _) = await LocalFoodClassifier.shared.classify(name: name)
            return category
        } else {
            // iOS 16及以下使用传统分类服务
            return FoodClassificationService.shared.classifyFood(name)
        }
    }
    
    private func mapCategory(_ category: String?) -> FoodCategory {
        guard let category = category else { return .other }
        
        switch category.lowercased() {
        // 英文分类
        case "meat": return .meat
        case "seafood": return .seafood
        case "vegetables": return .vegetables
        case "fruits": return .fruits
        case "eggs": return .eggs
        case "dairy": return .dairy
        case "grains": return .grains
        case "seasonings": return .condiments
        
        // 中文分类
        case "肉类": return .meat
        case "水产", "海鲜": return .seafood
        case "蔬菜": return .vegetables
        case "水果": return .fruits
        case "蛋类": return .eggs
        case "乳制品": return .dairy
        case "谷物": return .grains
        case "调料": return .condiments
        
        // 传统英文分类保持兼容
        case "beverages": return .beverages
        case "frozen": return .frozen
        case "canned": return .canned
        case "snacks": return .snacks
        default: return .other
        }
    }
    
    private func suggestStorageLocation(for category: FoodCategory) -> StorageLocation {
        switch category {
        case .vegetables, .fruits: return .refrigerator
        case .meat, .seafood: return .freezer
        case .eggs, .dairy: return .refrigerator
        case .grains, .condiments, .snacks: return .pantry
        case .beverages, .canned, .frozen, .other: return .pantry
        }
    }
    
    private func parseQuantityAndUnit(_ quantityString: String?) -> (Double, String) {
        guard let quantityString = quantityString else { 
            return (1.0, FoodItem.defaultUnit) 
        }
        
        let cleanString = quantityString
            .replacingOccurrences(of: "x", with: "")
            .replacingOccurrences(of: "×", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract number from string
        let numberRegex = try? NSRegularExpression(pattern: "\\d+(?:\\.\\d+)?", options: [])
        guard let match = numberRegex?.firstMatch(in: cleanString, options: [], range: NSRange(location: 0, length: cleanString.count)),
              let numberRange = Range(match.range, in: cleanString),
              let quantity = Double(String(cleanString[numberRange])) else {
            return (1.0, FoodItem.defaultUnit)
        }
        
        let remainingString = cleanString.replacingOccurrences(of: String(cleanString[numberRange]), with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        // Convert to standardized base units (g/mL/个) - same logic as other views
        if remainingString.contains("lbs") || remainingString.contains("磅") {
            return (quantity * 453.592, "g")
        } else if remainingString.contains("oz") || remainingString.contains("盎司") {
            return (quantity * 28.3495, "g")
        } else if remainingString.contains("kg") || remainingString.contains("公斤") || remainingString.contains("千克") {
            return (quantity * 1000, "g")
        } else if remainingString.contains("g") || remainingString.contains("克") {
            return (quantity, "g")
        } else if (remainingString.contains("l") && !remainingString.contains("ml")) || remainingString.contains("升") {
            return (quantity * 1000, "mL")
        } else if remainingString.contains("ml") || remainingString.contains("毫升") {
            return (quantity, "mL")
        } else if remainingString.contains("gal") || remainingString.contains("加仑") {
            return (quantity * 3785, "mL")
        } else if remainingString.contains("cups") || remainingString.contains("杯") {
            return (quantity * 240, "mL")
        } else if remainingString.contains("tbsp") || remainingString.contains("大勺") {
            return (quantity * 15, "mL")
        } else if remainingString.contains("tsp") || remainingString.contains("小勺") {
            return (quantity * 5, "mL")
        } else {
            // For other units like 个, 只, 袋, 包, 盒, 瓶, 罐, etc., use default unit
            return (quantity, FoodItem.defaultUnit)
        }
    }
    
    private func calculateExpirationDate(
        from purchaseDate: Date,
        category: FoodCategory,
        storageLocation: StorageLocation
    ) -> Date {
        let calendar = Calendar.current
        let baseShelfLife = getBaseShelfLife(for: category)
        let storageMultiplier = getStorageMultiplier(for: storageLocation)
        
        let adjustedDays = Int(Double(baseShelfLife) * storageMultiplier)
        return calendar.date(byAdding: .day, value: adjustedDays, to: purchaseDate) ?? purchaseDate
    }
    
    private func getBaseShelfLife(for category: FoodCategory) -> Int {
        switch category {
        case .vegetables: return 7
        case .fruits: return 5
        case .meat: return 3
        case .seafood: return 2
        case .eggs: return 21
        case .dairy: return 7
        case .grains: return 30
        case .condiments: return 365
        case .snacks: return 60
        case .beverages: return 14
        case .frozen: return 180
        case .canned: return 365
        case .other: return 14
        }
    }
    
    private func getStorageMultiplier(for location: StorageLocation) -> Double {
        switch location {
        case .freezer: return 3.0
        case .refrigerator: return 1.0
        case .pantry: return 0.8
        }
    }
}


enum ReceiptProcessorError: Error {
    case invalidReceiptData
    case failedToCreateFoodItem
    
    var localizedDescription: String {
        switch self {
        case .invalidReceiptData:
            return "receipt.error.invalid_data".localized
        case .failedToCreateFoodItem:
            return "receipt.error.create_item".localized
        }
    }
}

extension Notification.Name {
    static let receiptItemsAdded = Notification.Name("receiptItemsAdded")
}