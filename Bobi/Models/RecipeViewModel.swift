import SwiftUI
import SwiftData

enum Season {
    case spring, summer, autumn, winter
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = Date()
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

enum LoadingStage: Equatable {
    case preparing
    case analyzing
    case generating
    case generatingProgress(Double) // 新增：AI生成进度细分
    case formatting
    case completed
    
    var message: String {
        switch self {
        case .preparing: return "recipe.preparing.request".localized
        case .analyzing: return "recipe.analyzing.ingredients".localized
        case .generating: return "recipe.generating.recipes".localized
        case .generatingProgress(_): return "recipe.ai.thinking".localized
        case .formatting: return "recipe.formatting.results".localized
        case .completed: return "recipe.completed".localized
        }
    }
    
    var progress: Double {
        switch self {
        case .preparing: return 0.1
        case .analyzing: return 0.25
        case .generating: return 0.4
        case .generatingProgress(let progress): 
            // AI生成阶段从40%到85%，根据时间动态变化
            return 0.4 + (progress * 0.45)
        case .formatting: return 0.9
        case .completed: return 1.0
        }
    }
}

@MainActor
class RecipeViewModel: ObservableObject {
    @Published var userMessage = ""
    @Published var chatMessages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var loadingButtonId: String? = nil
    @Published var loadingProgress: String = ""
    @Published var currentLoadingStage: LoadingStage = .preparing
    @Published var lastRecommendation: ChatMessage? = nil
    @Published var showingFamilySetup = false
    @Published var showingNoIngredientsAlert = false
    @Published var cachedCalorieTarget: Int? = nil
    @Published var cachedAvailableIngredients: String = ""
    @Published var cachedIngredientsCount: Int = 0
    @Published var previousRequirement: String = ""
    @Published var previousButtonId: String = ""
    @Published var currentCookingStyle: String = ""
    
    private var loadingTask: Task<Void, Never>? = nil
    private var lastFamilyMembersHash: Int = 0
    private var lastFoodGroupsHash: Int = 0
    private var ingredientsHash: Int = 0
    private var cachedIngredientsDescription: String = ""
    private let maxChatMessages = 10
    private let aiService = AIService.shared
    private let localizationManager = LocalizationManager.shared
    private let themeManager = ThemeManager.shared
    
    var familyMembers: [FamilyMember] = []
    var foodGroups: [FoodGroup] = []
    
    func updateData(familyMembers: [FamilyMember], foodGroups: [FoodGroup]) {
        let _ = self.foodGroups.flatMap { $0.items }.count
        let _ = foodGroups.flatMap { $0.items }.count
        
        self.familyMembers = familyMembers
        self.foodGroups = foodGroups
        
        // 如果正在加载且没有食材，自动取消请求
        if isLoading && foodGroups.flatMap({ $0.items }).isEmpty {
            cancelCurrentRequest()
        }
        
        // 检查并重置孤立的加载状态（没有活跃的loadingTask但isLoading为true）
        if isLoading && loadingTask == nil {
            resetLoadingState()
        }
        
        // 由于类已标记为 @MainActor，直接调用即可
        updateCalorieCache()
    }
    
    var availableIngredients: String {
        // Calculate hash of current ingredients
        let items = foodGroups.flatMap { $0.items }
        let currentHash = items.map { "\($0.id)\($0.name)\($0.quantity)\($0.expirationDate?.timeIntervalSince1970 ?? 0)" }.joined().hashValue
        
        // Return cached result if hash hasn't changed
        if currentHash == ingredientsHash && !cachedIngredientsDescription.isEmpty {
            return cachedIngredientsDescription
        }
        
        // Update cache
        ingredientsHash = currentHash
        cachedIngredientsDescription = items
            .map { item in
                var description = "\(item.name): \(item.quantity)\(item.unit)"
                
                // 添加过期日期信息
                if let expirationDate = item.expirationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.locale = Locale(identifier: isEnglishMode ? "en" : "zh-Hans")
                    
                    if let daysUntilExpiration = item.daysUntilExpiration {
                        if daysUntilExpiration <= 0 {
                            description += isEnglishMode 
                                ? " (expired on \(formatter.string(from: expirationDate)))"
                                : "（已于\(formatter.string(from: expirationDate))过期）"
                        } else if daysUntilExpiration <= 3 {
                            description += isEnglishMode
                                ? " (expires in \(daysUntilExpiration) day\(daysUntilExpiration == 1 ? "" : "s"))"
                                : "（\(daysUntilExpiration)天后过期）"
                        } else if daysUntilExpiration <= 7 {
                            description += isEnglishMode
                                ? " (expires \(formatter.string(from: expirationDate)))"
                                : "（\(formatter.string(from: expirationDate))过期）"
                        }
                    }
                }
                
                return description
            }
            .joined(separator: ", ")
        
        return cachedIngredientsDescription
    }
    
    var availableIngredientsCount: Int {
        // 避免在计算属性中修改 @Published 属性，直接计算
        return foodGroups.flatMap { $0.items }.count
    }
    
    var totalCalorieTarget: Int {
        return cachedCalorieTarget ?? 0
    }
    
    var recommendedDishCount: Int {
        if familyMembers.isEmpty { return 0 }
        let memberCount = max(familyMembers.count, 1)
        if memberCount <= 2 { return 2 }
        if memberCount <= 4 { return 3 }
        return 4
    }
    
    var hasNoIngredients: Bool {
        availableIngredientsCount == 0
    }
    
    var hasInsufficientIngredients: Bool {
        availableIngredientsCount > 0 && availableIngredientsCount < recommendedDishCount * 2
    }
    
    var isEnglishMode: Bool {
        localizationManager.selectedLanguage == "en"
    }
    
    var isAdjustmentMode: Bool {
        lastRecommendation != nil
    }
    
    var dynamicDishCount: Int {
        recommendedDishCount
    }
    
    var currentSeason: Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .winter
        }
    }
    
    var familyInfo: String {
        let memberCount = familyMembers.count
        let adults = familyMembers.filter { $0.age >= 18 }.count
        let children = memberCount - adults
        
        var info = "家庭成员：\(memberCount)人"
        if adults > 0 { info += "（\(adults)位成人" }
        if children > 0 { info += "，\(children)位儿童" }
        if adults > 0 || children > 0 { info += "）" }
        
        let restrictions = familyMembers.flatMap { $0.dietaryRestrictions }
            .map { $0.rawValue }
            .filter { !$0.isEmpty }
        
        if !restrictions.isEmpty {
            info += "，饮食限制：\(restrictions.joined(separator: "、"))"
        }
        
        return info
    }
    
    var familyInfoEnglish: String {
        let memberCount = familyMembers.count
        let adults = familyMembers.filter { $0.age >= 18 }.count
        let children = memberCount - adults
        
        var info = "Family: \(memberCount) members"
        if adults > 0 { info += " (\(adults) adults" }
        if children > 0 { info += ", \(children) children" }
        if adults > 0 || children > 0 { info += ")" }
        
        let restrictions = familyMembers.flatMap { $0.dietaryRestrictions }
            .map { $0.rawValue }
            .filter { !$0.isEmpty }
        
        if !restrictions.isEmpty {
            info += ", Dietary restrictions: \(restrictions.joined(separator: ", "))"
        }
        
        return info
    }
    
    private func calculateCalorieTarget() -> Int {
        let total = Int(familyMembers.reduce(0) { $0 + $1.dailyCalorieTarget })
        return total
    }
    
    func updateCalorieCache() {
        let currentHash = familyMembers.hashValue
        if currentHash != lastFamilyMembersHash || cachedCalorieTarget == nil {
            cachedCalorieTarget = calculateCalorieTarget()
            lastFamilyMembersHash = currentHash
        }
    }
    
    private func updateIngredientsCache() {
        let currentHash = foodGroups.hashValue
        if currentHash != lastFoodGroupsHash {
            cachedAvailableIngredients = foodGroups.flatMap { $0.items }
                .map { "\($0.name): \($0.quantity)\($0.unit)" }
                .joined(separator: ", ")
            cachedIngredientsCount = foodGroups.flatMap { $0.items }.count
            lastFoodGroupsHash = currentHash
        }
    }
    
    func getDishCountForRecommendationType(_ message: String) -> Int {
        let lowercased = message.lowercased()
        
        if lowercased.contains("baby") || lowercased.contains("婴") || lowercased.contains("辅食") || 
           lowercased.contains("宝宝") || lowercased.contains("幼儿") || lowercased.contains("儿童") ||
           lowercased.contains("练习咀嚼") || lowercased.contains("chewing") || lowercased.contains("puree") {
            return 1
        }
        
        if lowercased.contains("spring") || lowercased.contains("summer") || lowercased.contains("autumn") || lowercased.contains("winter") ||
           lowercased.contains("春季") || lowercased.contains("夏日") || lowercased.contains("秋季") || lowercased.contains("冬日") ||
           lowercased.contains("时令") || lowercased.contains("季节") || lowercased.contains("清凉") || lowercased.contains("cool") {
            return familyMembers.count <= 3 ? 2 : 3
        }
        
        if lowercased.contains("elderly") || lowercased.contains("digest") || lowercased.contains("老年") || lowercased.contains("长者") || lowercased.contains("消化") {
            return familyMembers.count <= 3 ? 2 : 3
        }
        
        if lowercased.contains("breakfast") || lowercased.contains("早餐") {
            return familyMembers.count <= 3 ? 2 : 3
        }
        
        if lowercased.contains("weight") || lowercased.contains("减肥") || lowercased.contains("低热量") || lowercased.contains("low-calorie") {
            return 1
        }
        
        return recommendedDishCount
    }
    
    func isSpecialRecommendationType(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        
        if lowercased.contains("baby") || lowercased.contains("婴") || lowercased.contains("辅食") || 
           lowercased.contains("宝宝") || lowercased.contains("幼儿") || lowercased.contains("儿童") {
            return true
        }
        
        if lowercased.contains("weight") || lowercased.contains("减肥") || lowercased.contains("低热量") || lowercased.contains("low-calorie") || lowercased.contains("瘦身") {
            return true
        }
        
        if lowercased.contains("breakfast") || lowercased.contains("早餐") {
            return true
        }
        
        if lowercased.contains("spring") || lowercased.contains("summer") || lowercased.contains("autumn") || lowercased.contains("winter") ||
           lowercased.contains("春季") || lowercased.contains("夏日") || lowercased.contains("秋季") || lowercased.contains("冬日") ||
           lowercased.contains("时令") || lowercased.contains("季节") {
            return true
        }
        
        if lowercased.contains("diet") || lowercased.contains("diabetic") || lowercased.contains("糖尿病") {
            return true
        }
        
        return false
    }
    
    func isBabyFoodRecommendation(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("baby") || lowercased.contains("婴") || lowercased.contains("辅食") || 
               lowercased.contains("宝宝") || lowercased.contains("幼儿") || lowercased.contains("儿童") ||
               lowercased.contains("练习咀嚼") || lowercased.contains("chewing") || lowercased.contains("puree")
    }
    
    func getCalorieInfoForPrompt(for message: String) -> String {
        if familyMembers.isEmpty {
            return ""
        }
        
        if isSpecialRecommendationType(message) {
            return ""
        }
        
        if isEnglishMode {
            return " Total family daily calorie target: \(cachedCalorieTarget ?? 0) kcal for \(familyMembers.count) members."
        } else {
            return " 家庭日均总卡路里需求：\(cachedCalorieTarget ?? 0)千卡（\(familyMembers.count)人）。"
        }
    }
    
    func getDietaryRestrictionsForPrompt(for message: String = "") -> String {
        let isBabyFood = isBabyFoodRecommendation(message)
        
        let relevantMembers = familyMembers.filter { member in
            if isBabyFood {
                // 婴儿食物推荐只考虑婴儿成员（年龄0-2岁）
                return member.ageCategory == .baby
            } else {
                // 非婴儿食物推荐不考虑婴儿成员
                return member.ageCategory != .baby
            }
        }
        
        let restrictions = relevantMembers.flatMap { $0.dietaryRestrictions }
            .map { $0.localizedName }
            .filter { !$0.isEmpty }
        
        let customAllergies = relevantMembers.flatMap { $0.customAllergies }
            .filter { !$0.isEmpty }
        
        let allRestrictions = restrictions + customAllergies.map { isEnglishMode ? "Allergy: \($0)" : "过敏: \($0)" }
        
        return allRestrictions.isEmpty ? "" : " (\(allRestrictions.joined(separator: ", ")))"
    }
    
    func createFullPrompt(_ message: String, isPresetButton: Bool = true, buttonId: String? = nil) -> String {
        let dishCount = getDishCountForRecommendationType(message)
        let _ = lastRecommendation != nil && !isPresetButton
        let noRestrictions = isEnglishMode ? "None" : "无"
        let standardPortions = isEnglishMode ? "Standard portions" : "标准分量"
        
        let restrictions = getDietaryRestrictionsForPrompt(for: message)
        let calories = getCalorieInfoForPrompt(for: message)
        let ingredients = availableIngredients
        let expiringInfo = getExpiringIngredientsInfo()
        
        let focus = getOptimizedCreativityFocus()
        let style = getOptimizedCookingStyle(for: message, isPresetButton: isPresetButton)
        
        let baseParams = isEnglishMode
            ? "[DISH_COUNT]: \(dishCount)\n[Dietary Restrictions]: \(restrictions.isEmpty ? noRestrictions : restrictions)\n[CALORIE_INFO]: \(calories.isEmpty ? standardPortions : calories)\n[Creative Focus]: \(focus)\n[Cooking Style]: \(style)\n\n[Available Ingredients]:\n\(ingredients)\n\n\(expiringInfo)"
            : "[DISH_COUNT]: \(dishCount)\n[饮食限制]: \(restrictions.isEmpty ? noRestrictions : restrictions)\n[CALORIE_INFO]: \(calories.isEmpty ? standardPortions : calories)\n[创意焦点]: \(focus)\n[烹饪风格]: \(style)\n\n[现有食材]:\n\(ingredients)\n\n\(expiringInfo)"
        
        if isAdjustmentMode, let lastRec = lastRecommendation {
            let dishNames = extractDishNamesFromRecommendation(lastRec.content)
            var adjustmentSection = ""
            
            // Check if this is the same button clicked again
            if !previousButtonId.isEmpty && previousButtonId == (buttonId ?? "") {
                // Same button clicked again - treat as regeneration, not adjustment
                adjustmentSection = isEnglishMode
                    ? "[Previous Dishes]: \(dishNames)\n\n[Regenerate Request]:\n\(message)"
                    : "[之前的菜]: \(dishNames)\n\n[重新生成要求]:\n\(message)"
            } else if !previousRequirement.isEmpty && !previousButtonId.isEmpty {
                // Different request - this is a real adjustment
                adjustmentSection = isEnglishMode
                    ? "[Previous Dishes]: \(dishNames)\n\n[Previous Requirement]:\n\(previousRequirement)\n\n[Adjustment Request]:\n\(message)"
                    : "[之前的菜]: \(dishNames)\n\n[之前的要求]:\n\(previousRequirement)\n\n[调整要求]:\n\(message)"
            } else {
                // First adjustment after initial recommendation
                adjustmentSection = isEnglishMode
                    ? "[Previous Dishes]: \(dishNames)\n\n[Adjustment Request]:\n\(message)"
                    : "[之前的菜]: \(dishNames)\n\n[调整要求]:\n\(message)"
            }
            return baseParams + adjustmentSection
        } else {
            let requestSection = isEnglishMode
                ? "[Other Requests]:\n\(message)"
                : "[其他需求]:\n\(message)"
            return baseParams + requestSection
        }
    }
    
    func getExpiringIngredientsInfo() -> String {
        let allItems = foodGroups.flatMap { $0.items }
        
        // 获取即将过期的食材（7天内）
        let expiringItems = allItems.filter { item in
            if let days = item.daysUntilExpiration {
                return days <= 7 && days >= 0
            }
            return false
        }.sorted { (item1, item2) in
            // 按过期时间排序，最紧急的排在前面
            let days1 = item1.daysUntilExpiration ?? Int.max
            let days2 = item2.daysUntilExpiration ?? Int.max
            return days1 < days2
        }
        
        if expiringItems.isEmpty {
            return ""
        }
        
        let urgentItems = expiringItems.filter { ($0.daysUntilExpiration ?? 0) <= 2 }
        let soonItems = expiringItems.filter { 
            let days = $0.daysUntilExpiration ?? 0
            return days > 2 && days <= 7
        }
        
        var expiringInfo = ""
        
        if isEnglishMode {
            expiringInfo += "[🚨 URGENT PRIORITY INGREDIENTS]:\n"
            if !urgentItems.isEmpty {
                for item in urgentItems {
                    let days = item.daysUntilExpiration ?? 0
                    let status = days <= 0 ? "EXPIRED" : (days == 1 ? "expires TOMORROW" : "expires in \(days) days")
                    expiringInfo += "- \(item.name): \(item.quantity)\(item.unit) (\(status))\n"
                }
            }
            
            if !soonItems.isEmpty {
                expiringInfo += "\n[⚠️ SOON EXPIRING]:\n"
                for item in soonItems {
                    let days = item.daysUntilExpiration ?? 0
                    expiringInfo += "- \(item.name): \(item.quantity)\(item.unit) (expires in \(days) days)\n"
                }
            }
            
            expiringInfo += "\n**IMPORTANT**: Please PRIORITIZE using ingredients from the URGENT list in your recipes to minimize food waste. Try to create dishes that can utilize multiple expiring ingredients together.\n\n"
        } else {
            expiringInfo += "[🚨 紧急优先食材]:\n"
            if !urgentItems.isEmpty {
                for item in urgentItems {
                    let days = item.daysUntilExpiration ?? 0
                    let status = days <= 0 ? "已过期" : (days == 1 ? "明天过期" : "\(days)天后过期")
                    expiringInfo += "- \(item.name): \(item.quantity)\(item.unit) (\(status))\n"
                }
            }
            
            if !soonItems.isEmpty {
                expiringInfo += "\n[⚠️ 即将过期]:\n"
                for item in soonItems {
                    let days = item.daysUntilExpiration ?? 0
                    expiringInfo += "- \(item.name): \(item.quantity)\(item.unit) (\(days)天后过期)\n"
                }
            }
            
            expiringInfo += "\n**重要提醒**: 请优先使用「紧急优先食材」列表中的食材，尽量创作能同时利用多种即将过期食材的菜品，减少食物浪费。\n\n"
        }
        
        return expiringInfo
    }
    
    func getOptimizedCreativityFocus() -> String {
        let focusOptions = isEnglishMode 
            ? [
                "Nutritional Balance",
                "Umami Layering", 
                "Seasonal Focus",
                "Easy Scaling",
                "Color Harmony",
                "Texture Contrast",
                "Regional Authenticity",
                "Quick Preparation",
                "Flavor Balance",
                "Aromatic Complexity",
                "Temperature Contrast",
                "Digestive Wellness",
                "Energy Boosting",
                "Immune Support",
                "Anti-inflammatory"
            ]
            : [
                "营养均衡",
                "鲜味层次",
                "时令食材", 
                "易于调节",
                "色彩和谐",
                "口感对比",
                "地道风味",
                "快速便捷",
                "味道平衡",
                "香味层次",
                "温度对比",
                "养胃护肠",
                "提神醒脑",
                "增强免疫",
                "消炎降火"
            ]
        
        // Use random selection for variety on each request
        let index = Int.random(in: 0..<focusOptions.count)
        return focusOptions[index]
    }
    
    func getOptimizedCookingStyle(for message: String, isPresetButton: Bool = true) -> String {
        // Always use general style options for consistency
        let styleOptions: [String]
        
        if isEnglishMode {
            styleOptions = [
                "Balanced & Harmonious: Well-rounded flavors with complementary textures and tastes.",
                "Simple & Satisfying: Straightforward cooking methods that highlight natural flavors.",
                "Fresh & Vibrant: Emphasis on bright, clean tastes and colorful presentation.",
                "Warm & Comforting: Cozy, homestyle approach with familiar cooking techniques.",
                "Light & Refreshing: Emphasis on digestibility and clean, crisp flavors.",
                "Rich & Savory: Deep, complex flavors with satisfying umami elements.",
                "Quick & Efficient: Fast cooking methods without compromising taste quality.",
                "Traditional & Reliable: Time-tested cooking approaches with proven combinations."
            ]
        } else {
            styleOptions = [
                "均衡和谐：口味搭配合理，质地层次互补，营养全面。",
                "简单朴实：烹饪方法简单，突出食材本味，易于掌握。",
                "清新明快：味道清爽干净，色彩搭配丰富，口感清淡。",
                "温馨暖心：家常烹饪手法，味道温和亲切，老少皆宜。",
                "清淡养生：注重消化吸收，口味清爽不腥腻，健康为主。",
                "浓郁香醇：味道层次丰富，鲜味突出，口感饱满。",
                "快手便捷：制作快速高效，不失美味品质，适合快节奏。",
                "传统可靠：经典搭配组合，烹饪方法成熟，口味稳定。"
            ]
        }
        
        // For consistency, use stored style if available and this is an adjustment
        let isAdjustment = lastRecommendation != nil && !isPresetButton
        if isAdjustment && !currentCookingStyle.isEmpty {
            return currentCookingStyle
        }
        
        // Use random selection for new requests
        let index = Int.random(in: 0..<styleOptions.count)
        let selectedStyle = styleOptions[index]
        
        // Store the style for future consistency
        currentCookingStyle = selectedStyle
        return selectedStyle
    }
    
    // 从之前的推荐中提取菜名
    func extractDishNamesFromRecommendation(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var dishNames: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 匹配 [菜名] 或 [Dish Name] 格式
            if trimmed.hasPrefix("[") && trimmed.contains("]") {
                let firstBracket = trimmed.firstIndex(of: "[")!
                let lastBracket = trimmed.firstIndex(of: "]")!
                let tag = String(trimmed[trimmed.index(after: firstBracket)..<lastBracket])
                
                if tag == "菜名" || tag == "Dish Name" {
                    // 提取菜名内容
                    let nameStart = trimmed.index(after: lastBracket)
                    let dishName = String(trimmed[nameStart...]).trimmingCharacters(in: .whitespaces)
                    if !dishName.isEmpty {
                        dishNames.append(dishName)
                    }
                }
            }
        }
        
        return dishNames.joined(separator: ", ")
    }
    
    func sendMessage() {
        guard !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sendQuickMessage(userMessage, isPresetButton: false, buttonId: "custom_input")
        userMessage = ""
    }
    
    func sendQuickMessage(_ message: String, isPresetButton: Bool = true, buttonId: String? = nil) {
        guard !isLoading else { return }
        
        if familyMembers.isEmpty {
            showingFamilySetup = true
            return
        }
        
        let userChatMessage = ChatMessage(content: message, isUser: true)
        
        if chatMessages.count >= maxChatMessages {
            if chatMessages.count >= 2 {
                chatMessages.removeFirst(2)
            }
        }
        
        chatMessages.append(userChatMessage)
        
        isLoading = true
        loadingButtonId = buttonId
        currentLoadingStage = .preparing
        
        loadingTask = Task {
            do {
                currentLoadingStage = .preparing
                
                try await Task.sleep(nanoseconds: 200_000_000)
                currentLoadingStage = .analyzing
                
                // Save requirement from preset button
                if isPresetButton {
                    previousRequirement = message
                    previousButtonId = buttonId ?? ""
                }
                
                let _ = lastRecommendation != nil && !isPresetButton
                let _ = getDishCountForRecommendationType(message)
                let fullPrompt = createFullPrompt(message, isPresetButton: isPresetButton, buttonId: buttonId)
                let language = isEnglishMode ? "en" : "zh-Hans"
                
                
                currentLoadingStage = .generating
                let _ = Date()
                
                // 🚀 启动智能进度估算
                let progressTask = Task {
                    await simulateProgressiveLoading()
                }
                
                let response = try await aiService.generateRecipe(
                    message: fullPrompt, 
                    language: language
                )
                
                // 停止进度模拟
                progressTask.cancel()
                
                currentLoadingStage = .formatting
                try await Task.sleep(nanoseconds: 300_000_000)
                
                currentLoadingStage = .completed
                
                
                let aiMessage = ChatMessage(content: response, isUser: false)
                chatMessages.append(aiMessage)
                lastRecommendation = aiMessage
                
                try await Task.sleep(nanoseconds: 500_000_000)
                
                resetLoadingState()
                
            } catch is CancellationError {
                resetLoadingState()
            } catch {
                
                let errorContent: String
                if let aiError = error as? AIServiceError {
                    switch aiError {
                    case .dailyLimitExceeded:
                        // 免费AI用完，显示升级提示
                        errorContent = aiError.localizedDescription + "\n\n" + 
                                     "ai.upgrade.tip.description".localized
                    default:
                        errorContent = aiError.localizedDescription
                    }
                } else {
                    errorContent = "recipe.error.message".localized
                }
                
                let errorMessage = ChatMessage(
                    content: errorContent,
                    isUser: false
                )
                chatMessages.append(errorMessage)
                resetLoadingState()
            }
        }
    }
    
    func resetLoadingState() {
        isLoading = false
        loadingButtonId = nil
        currentLoadingStage = .preparing
        loadingTask = nil
    }
    
    func cancelCurrentRequest() {
        loadingTask?.cancel()
        resetLoadingState()
    }
    
    func clearChatOnLanguageChange(_ newLanguage: String) {
        // 由于类已标记为 @MainActor，可以直接更新属性
        chatMessages.removeAll()
        lastRecommendation = nil
        previousRequirement = ""
        previousButtonId = ""
        currentCookingStyle = ""
    }
    
    // 🚀 智能进度估算：在AI调用期间动态更新进度
    @MainActor
    private func simulateProgressiveLoading() async {
        var currentProgress: Double = 0.0
        let maxProgress: Double = 0.95 // 不超过95%，留给真实完成状态
        let updateInterval: UInt64 = 800_000_000 // 0.8秒更新一次
        
        // 前5秒快速增长（用户感觉很快）
        let fastPhaseSteps = 6
        let fastStepSize = 0.6 / Double(fastPhaseSteps) // 前60%在6步内完成
        
        for _ in 0..<fastPhaseSteps {
            guard !Task.isCancelled else { return }
            currentProgress += fastStepSize
            currentLoadingStage = .generatingProgress(min(currentProgress, maxProgress))
            try? await Task.sleep(nanoseconds: updateInterval)
        }
        
        // 之后缓慢增长（让用户知道还在进行中）
        let slowStepSize = 0.05 // 每次增加5%
        
        while currentProgress < maxProgress && !Task.isCancelled {
            currentProgress += slowStepSize
            let cappedProgress = min(currentProgress, maxProgress)
            currentLoadingStage = .generatingProgress(cappedProgress)
            
            // 随着进度增加，更新间隔也增加（越来越慢）
            let dynamicInterval = updateInterval + UInt64(currentProgress * 1_200_000_000) // 最长2秒
            try? await Task.sleep(nanoseconds: dynamicInterval)
        }
    }
}