import Foundation

struct UnitDisplayHelper {
    
    // MARK: - 单位显示配置
    static let volumeThreshold: Double = 1000 // mL转L的阈值
    static let weightThreshold: Double = 1000 // g转kg的阈值
    
    // MARK: - 单位类型检测
    enum UnitType {
        case volume // 体积单位
        case weight // 重量单位
        case count  // 计数单位
        case unknown
    }
    
    static func getUnitType(_ unit: String) -> UnitType {
        let normalizedUnit = unit.lowercased()
        
        if ["ml", "mL", "毫升", "l", "L", "升", "gal", "gallon", "加仑", "cup", "cups", "杯"].contains(normalizedUnit) {
            return .volume
        } else if ["g", "克", "kg", "千克", "公斤", "lb", "lbs", "磅", "oz", "盎司", "斤", "两"].contains(normalizedUnit) {
            return .weight
        } else if ["个", "pcs", "item", "打", "只", "瓶", "罐", "盒", "袋", "container"].contains(normalizedUnit) {
            return .count
        }
        
        return .unknown
    }
    
    // MARK: - 智能单位显示
    static func formatQuantityWithUnit(_ quantity: Double, unit: String) -> String {
        let unitType = getUnitType(unit)
        let isChineseLocale = LocalizationManager.shared.selectedLanguage == "zh-Hans"
        
        switch unitType {
        case .volume:
            return formatVolumeUnit(quantity, originalUnit: unit, isChineseLocale: isChineseLocale)
        case .weight:
            return formatWeightUnit(quantity, originalUnit: unit, isChineseLocale: isChineseLocale)
        case .count:
            return formatCountUnit(quantity, originalUnit: unit, isChineseLocale: isChineseLocale)
        case .unknown:
            // 对于未知单位，直接显示原单位
            return String(format: "%.1f %@", quantity, unit)
        }
    }
    
    // MARK: - 体积单位格式化
    private static func formatVolumeUnit(_ quantity: Double, originalUnit: String, isChineseLocale: Bool) -> String {
        // 统一转换为毫升进行计算
        var quantityInML = quantity
        
        let normalizedUnit = originalUnit.lowercased()
        if ["l", "L", "升"].contains(normalizedUnit) {
            quantityInML = quantity * 1000
        } else if ["gal", "gallon", "加仑"].contains(normalizedUnit) {
            quantityInML = quantity * 3785
        } else if ["cup", "杯"].contains(normalizedUnit) {
            quantityInML = quantity * 240  // 1 cup = 240mL
        }
        
        // 判断是否需要转换为升
        if quantityInML >= volumeThreshold {
            let quantityInL = quantityInML / 1000
            let unitText = isChineseLocale ? "升" : "L"
            return String(format: "%.2f %@", quantityInL, unitText)
        } else {
            let unitText = isChineseLocale ? "毫升" : "mL"
            return String(format: "%.0f %@", quantityInML, unitText)
        }
    }
    
    // MARK: - 重量单位格式化
    private static func formatWeightUnit(_ quantity: Double, originalUnit: String, isChineseLocale: Bool) -> String {
        // 统一转换为克进行计算
        var quantityInG = quantity
        
        let normalizedUnit = originalUnit.lowercased()
        if ["kg", "千克", "公斤"].contains(normalizedUnit) {
            quantityInG = quantity * 1000
        } else if ["lb", "lbs", "磅"].contains(normalizedUnit) {
            quantityInG = quantity * 453.592
        } else if ["oz", "盎司"].contains(normalizedUnit) {
            quantityInG = quantity * 28.3495
        } else if ["斤"].contains(normalizedUnit) {
            quantityInG = quantity * 500
        } else if ["两"].contains(normalizedUnit) {
            quantityInG = quantity * 50
        }
        
        // 判断是否需要转换为千克
        if quantityInG >= weightThreshold {
            let quantityInKG = quantityInG / 1000
            let unitText = isChineseLocale ? "千克" : "kg"
            return String(format: "%.2f %@", quantityInKG, unitText)
        } else {
            let unitText = isChineseLocale ? "克" : "g"
            return String(format: "%.0f %@", quantityInG, unitText)
        }
    }
    
    // MARK: - 计数单位格式化
    private static func formatCountUnit(_ quantity: Double, originalUnit: String, isChineseLocale: Bool) -> String {
        let intQuantity = Int(quantity)
        
        // 处理特殊计数单位
        if originalUnit == "打" {
            let totalCount = intQuantity * 12
            let unitText = isChineseLocale ? "个" : "items"
            return "\(totalCount) \(unitText)"
        }
        
        // 标准化显示
        let displayUnit: String
        if originalUnit == "item" || originalUnit == "pcs" {
            displayUnit = isChineseLocale ? "个" : "pcs"
        } else if originalUnit == "个" {
            displayUnit = isChineseLocale ? "个" : "pcs"
        } else {
            displayUnit = originalUnit
        }
        
        return "\(intQuantity) \(displayUnit)"
    }
    
    // MARK: - 检查是否需要单位提示
    static func needsUnitGuidance(name: String, unit: String, quantity: Double) -> Bool {
        let unitType = getUnitType(unit)
        
        // 只对计数单位且可能需要具体单位的食物提供提示
        guard unitType == .count else { return false }
        
        let foodName = name.lowercased()
        
        // 液体类食物通常需要体积单位
        let liquidFoods = ["牛奶", "酸奶", "果汁", "饮料", "水", "汽水", "啤酒", "红酒", "白酒", 
                          "milk", "juice", "drink", "water", "soda", "beer", "wine", "yogurt"]
        
        for liquid in liquidFoods {
            if foodName.contains(liquid) {
                return true
            }
        }
        
        // 使用 FoodClassificationService 检查是否需要重量单位
        if FoodClassificationService.shared.needsWeightUnit(foodName) {
            return true
        }
        
        return false
    }
    
    // MARK: - 获取建议单位
    static func getSuggestedUnits(for foodName: String) -> [String] {
        let foodName = foodName.lowercased()
        let isChineseLocale = LocalizationManager.shared.selectedLanguage == "zh-Hans"
        
        // 液体类食物 - 酸奶单独处理
        if foodName.contains("酸奶") || foodName.contains("yogurt") {
            return isChineseLocale ? ["毫升", "升"] : ["mL", "L"]
        }
        
        let liquidFoods = ["牛奶", "果汁", "饮料", "水", "汽水", "啤酒", "红酒", "白酒",
                          "milk", "juice", "drink", "water", "soda", "beer", "wine"]
        
        for liquid in liquidFoods {
            if foodName.contains(liquid) {
                return isChineseLocale ? ["毫升", "升", "杯", "加仑"] : ["mL", "L", "cups", "gal"]
            }
        }
        
        // 使用 FoodClassificationService 检查是否需要重量单位
        if FoodClassificationService.shared.needsWeightUnit(foodName) {
            return isChineseLocale ? ["克", "千克", "盎司", "磅"] : ["g", "kg", "oz", "lb"]
        }
        
        // 默认建议
        return isChineseLocale ? ["个"] : ["pcs"]
    }
    
    // MARK: - 单位转换说明
    static func getConversionExplanation(quantity: Double, unit: String) -> String? {
        let unitType = getUnitType(unit)
        let normalizedUnit = unit.lowercased()
        
        // 只对非标准单位显示转换说明
        switch unitType {
        case .weight:
            if ["kg", "千克", "公斤"].contains(normalizedUnit) {
                let grams = Int(quantity * 1000)
                return String(format: "unit.conversion.weight.to.g".localized, "\(grams)")
            } else if ["lb", "磅", "lbs"].contains(normalizedUnit) {
                let grams = Int(quantity * 453.592)
                return String(format: "unit.conversion.weight.to.g".localized, "\(grams)")
            } else if ["oz", "盎司"].contains(normalizedUnit) {
                let grams = Int(quantity * 28.3495)
                return String(format: "unit.conversion.weight.to.g".localized, "\(grams)")
            } else if ["斤"].contains(normalizedUnit) {
                let grams = Int(quantity * 500)
                return String(format: "unit.conversion.weight.to.g".localized, "\(grams)")
            } else if ["两"].contains(normalizedUnit) {
                let grams = Int(quantity * 50)
                return String(format: "unit.conversion.weight.to.g".localized, "\(grams)")
            }
        case .volume:
            if ["l", "L", "升"].contains(normalizedUnit) {
                let ml = Int(quantity * 1000)
                return String(format: "unit.conversion.volume.to.ml".localized, "\(ml)")
            } else if ["gal", "gallon", "加仑"].contains(normalizedUnit) {
                let ml = Int(quantity * 3785)
                return String(format: "unit.conversion.volume.to.ml".localized, "\(ml)")
            } else if ["cup", "cups", "杯"].contains(normalizedUnit) {
                let ml = Int(quantity * 240)
                return String(format: "unit.conversion.volume.to.ml".localized, "\(ml)")
            }
        case .count:
            // 对于计数单位，如果不是"个"或"pcs"，显示转换说明
            if !["个", "pcs", "item"].contains(normalizedUnit) {
                let count = Int(quantity)
                return String(format: "unit.conversion.count".localized, "\(count)")
            }
        case .unknown:
            break
        }
        
        return nil
    }
}