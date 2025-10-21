import Foundation
import SwiftData
import SwiftUI

// MARK: - Home Status Service

/// 主页状态数据聚合服务
@MainActor
class HomeStatusService: ObservableObject {
    static let shared = HomeStatusService()
    
    private let aiService = AIService.shared
    private let localizationManager = LocalizationManager.shared
    private let weatherKitService = WeatherKitService.shared
    private let homePagePrompts = HomePagePrompts()
    private let enhancedGreetingService = EnhancedGreetingService.shared
    private var modelContext: ModelContext?
    
    // 用户心情状态
    @Published var currentMood: UserMood?
    
    // 心情状态追踪
    @Published var lastMoodUpdateTime: Date?
    @Published var shouldPromptMoodSelection: Bool = false
    
    // 心情过期时间（6小时）
    private let moodExpirationInterval: TimeInterval = 21600 // 6 hours
    
    // 缓存机制
    private var cachedHomeStatus: HomeStatusData?
    private var lastCacheTime: Date?
    private let cacheExpiration: TimeInterval = 21600 // 6小时缓存
    
    // AI生成内容的单独缓存
    private var cachedMealSuggestion: MealSuggestion?
    private var cachedLifeTips: [LifeTip]?
    private var lastAiGenerationTime: Date?
    private var lastMoodForAiGeneration: UserMood?
    private var lastWeatherForAiGeneration: WeatherInfo?
    private let aiCacheExpiration: TimeInterval = 21600 // 6小时AI缓存
    
    // 多样性管理
    private var recentDishNames: [String] = []
    private let maxRecentDishes = 5 // 记录最近5道菜品，避免重复
    
    // AI服务状态跟踪
    private var lastAiGenerationFailed: Bool = false
    private var isDailyLimitExceeded: Bool = false
    
    // 加载状态管理
    @Published var isMealSuggestionLoading: Bool = false
    
    private init() {
        // 启动时请求位置权限
        weatherKitService.requestLocationPermission()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clearCache()
                // 重新检查心情状态，确保UI正确显示
                self?.updateMoodPromptStatus()
                
                // 如果用户已经有有效的心情且不需要重新选择，自动重新生成AI内容
                if let self = self,
                   self.currentMood != nil,
                   !self.shouldPromptMoodSelection {
                    print("DEBUG: 语言切换后自动重新生成AI内容")
                    await self.generateAiContentInBackground()
                }
            }
        }
        
        // 启动时检查心情状态
        checkMoodStatus()
        
        // 确保初始加载状态为false
        isMealSuggestionLoading = false
        
        // 注释掉自动生成AI内容，只有在用户选择心情后才生成
        // Task {
        //     try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒延迟
        //     await generateAiContentInBackground()
        // }
        
        // 设置定时器，定期检查心情状态
        setupMoodStatusTimer()
    }
    
    /// 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// 设置用户心情
    func setUserMood(_ mood: UserMood) {
        let moodChanged = currentMood != mood
        currentMood = mood
        lastMoodUpdateTime = Date() // 记录心情更新时间
        shouldPromptMoodSelection = false // 清除提醒状态
        
        if moodChanged {
            // 只有心情真的改变时才清除AI缓存
            cachedMealSuggestion = nil
            cachedLifeTips = nil
            lastAiGenerationTime = nil
            lastMoodForAiGeneration = nil
            lastWeatherForAiGeneration = nil
            
            // 清除UserDefaults中的缓存数据
            UserDefaults.standard.removeObject(forKey: "cachedMealSuggestion")
            UserDefaults.standard.removeObject(forKey: "lastAiGenerationTime")
            UserDefaults.standard.removeObject(forKey: "lastMoodForAiGeneration")
            
            // 注意：AI内容生成现在由ViewModel控制，不在这里重复生成
            
            print("DEBUG: 心情改变为 \(mood.mood.rawValue)，已清除AI缓存")
        }
        
        // 保存心情状态到UserDefaults
        saveMoodStatusToUserDefaults()
    }
    
    /// 生成主页状态数据
    func generateHomeStatusData() async -> HomeStatusData {
        // 检查缓存
        if let cached = cachedHomeStatus,
           let lastCache = lastCacheTime,
           Date().timeIntervalSince(lastCache) < cacheExpiration {
            return cached
        }
        
        // 并行获取基础数据
        async let weatherInfo = generateWeatherInfo()
        async let dailyCalorieNeeds = calculateDailyCalorieNeeds()
        
        // 生成增强的问候语，需要天气信息
        let weather = await weatherInfo
        let greeting = await enhancedGreetingService.generateEnhancedGreeting(
            weather: weather,
            mood: currentMood,
            isFirstLaunchToday: isFirstLaunchToday()
        )
        
        // AI内容使用缓存或简单替代
        let lifeTips = await getLifeTipsWithCache()
        let mealSuggestion = await getMealSuggestionWithCache()
        
        let homeStatusData = HomeStatusData(
            greeting: greeting,
            weatherInfo: weather,
            dailyCalorieNeeds: await dailyCalorieNeeds,
            inventorySnapshot: InventorySnapshot(), // 简化为空
            mealSuggestion: mealSuggestion,
            shoppingStatus: ShoppingStatus(), // 简化为空
            lifeTips: lifeTips,
            lastUpdated: Date()
        )
        
        // 更新缓存
        cachedHomeStatus = homeStatusData
        lastCacheTime = Date()
        
        return homeStatusData
    }
    
    /// 强制刷新数据
    func refreshData() async -> HomeStatusData {
        cachedHomeStatus = nil
        lastCacheTime = nil
        return await generateHomeStatusData()
    }
    
    /// 主动生成AI内容（用于用户选择心情后）
    func generateAiContent() async {
        await generateAiContentInBackground()
    }
    
    /// 检查是否有AI生成的内容可用
    func hasAiContentAvailable() -> Bool {
        return cachedMealSuggestion != nil && cachedLifeTips != nil
    }
    
    /// 检查AI生成是否失败
    func isAiGenerationFailed() -> Bool {
        return lastAiGenerationFailed && currentMood != nil && !shouldPromptMoodSelection
    }
    
    /// 检查是否达到每日AI限额
    func isDailyLimitReached() -> Bool {
        return isDailyLimitExceeded && currentMood != nil && !shouldPromptMoodSelection
    }
    
    /// 重置AI生成失败状态
    func resetAiGenerationFailedState() {
        lastAiGenerationFailed = false
        isDailyLimitExceeded = false
    }
    
    /// 清除所有缓存（语言变化时调用）
    private func clearCache() {
        cachedHomeStatus = nil
        lastCacheTime = nil
        cachedMealSuggestion = nil
        cachedLifeTips = nil
        lastAiGenerationTime = nil
        lastMoodForAiGeneration = nil
        lastWeatherForAiGeneration = nil
        
        // 重置加载状态
        isMealSuggestionLoading = false
        lastAiGenerationFailed = false
        isDailyLimitExceeded = false
        
        // 清除UserDefaults中的缓存数据
        UserDefaults.standard.removeObject(forKey: "cachedMealSuggestion")
        UserDefaults.standard.removeObject(forKey: "lastAiGenerationTime")
        UserDefaults.standard.removeObject(forKey: "lastMoodForAiGeneration")
        
        // 同时清除天气服务的缓存
        weatherKitService.clearCache()
        
        print("DEBUG: 语言变化，已清除所有缓存并重置加载状态")
    }
    
    // MARK: - AI Content Management
    
    
    /// 获取带缓存的餐品建议
    private func getMealSuggestionWithCache() async -> MealSuggestion? {
        // 如果需要提醒用户选择心情，不生成任何推荐
        if shouldPromptMoodSelection {
            print("DEBUG: 需要选择心情，跳过AI推荐生成")
            return nil
        }
        
        // 检查是否有有效缓存
        if let cached = cachedMealSuggestion,
           let lastGeneration = lastAiGenerationTime,
           Date().timeIntervalSince(lastGeneration) < aiCacheExpiration,
           shouldUseCachedAiContent() {
            return cached
        }
        
        // 没有缓存时，不主动生成AI推荐
        // AI内容只有在用户手动选择心情后才生成（通过generateAiContent()调用）
        
        // 没有心情信息时，不返回任何建议
        return nil
    }
    
    /// 获取带缓存的生活小贴士
    private func getLifeTipsWithCache() async -> [LifeTip] {
        // 检查是否有有效缓存
        if let cached = cachedLifeTips,
           let lastGeneration = lastAiGenerationTime,
           Date().timeIntervalSince(lastGeneration) < aiCacheExpiration,
           shouldUseCachedAiContent() {
            return cached
        }
        
        // 没有缓存时返回简单贴士
        return generateSimpleLifeTips()
    }
    
    /// 检查是否应该使用缓存的AI内容
    private func shouldUseCachedAiContent() -> Bool {
        // 如果从来没有生成过AI内容，不使用缓存
        guard let lastGeneration = lastAiGenerationTime else {
            print("DEBUG: 从未生成过AI内容，不使用缓存")
            return false
        }
        
        // 检查缓存是否过期
        if Date().timeIntervalSince(lastGeneration) >= aiCacheExpiration {
            print("DEBUG: AI缓存已过期，不使用缓存")
            return false
        }
        
        // 如果心情发生了显著变化，则不使用缓存
        if let lastMood = lastMoodForAiGeneration,
           let currentMood = currentMood,
           lastMood.mood != currentMood.mood {
            print("DEBUG: 心情从 \(lastMood.mood.rawValue) 变为 \(currentMood.mood.rawValue)，不使用缓存")
            return false
        }
        
        // 如果之前没有心情，现在有了心情，不使用缓存
        if lastMoodForAiGeneration == nil && currentMood != nil {
            return false
        }
        
        return true
    }
    
    /// 后台生成AI内容（专注于生活鼓励和推荐）
    private func generateAiContentInBackground() async {
        // 如果需要提醒用户选择心情，不生成AI内容
        if shouldPromptMoodSelection {
            print("DEBUG: 需要选择心情，跳过后台AI内容生成")
            // 确保加载状态为false
            await MainActor.run {
                isMealSuggestionLoading = false
            }
            return
        }
        
        let weather = await generateWeatherInfo()
        
        // 检查是否需要重新生成AI内容
        let shouldRegenerateAI: Bool = {
            // 如果之前没有生成过，一定要生成
            guard let _ = lastAiGenerationTime else {
                return true
            }
            
            // 检查是否应该使用缓存（这里会考虑心情变化等因素）
            if !shouldUseCachedAiContent() {
                return true
            }
            
            // 如果现在有天气信息，但之前没有，需要重新生成
            if weather != nil && lastWeatherForAiGeneration == nil {
                return true
            }
            
            // 如果现在没有天气信息，但之前有，需要重新生成（切换到心情+时间模式）
            if weather == nil && lastWeatherForAiGeneration != nil {
                return true
            }
            
            // 如果都有天气信息，检查天气是否显著变化
            if let currentWeather = weather,
               let lastWeather = lastWeatherForAiGeneration {
                let weatherChanged = currentWeather.condition != lastWeather.condition || 
                                   abs(currentWeather.temperature - lastWeather.temperature) > 3
                return weatherChanged
            }
            
            // 其他情况不需要重新生成
            return false
        }()
        
        if !shouldRegenerateAI {
            return
        }
        
        // 生成AI餐品推荐
        let mealSuggestion = await generateSimpleWeatherMoodSuggestionWithAI(weather: weather)
        
        // 生成简单生活贴士
        let tips = generateSimpleLifeTips()
        
        // 更新缓存
        await MainActor.run {
            self.cachedMealSuggestion = mealSuggestion
            self.cachedLifeTips = tips
            self.lastAiGenerationTime = Date()
            self.lastMoodForAiGeneration = self.currentMood
            self.lastWeatherForAiGeneration = weather
            
            // 持久化缓存到UserDefaults
            self.saveMealSuggestionCache()
            
            // 通知数据已更新，需要刷新缓存
            self.cachedHomeStatus = nil
            self.lastCacheTime = nil
            
            // 发布通知，触发UI更新
            NotificationCenter.default.post(name: .homeStatusDataUpdated, object: nil)
        }
    }
    
    /// 生成简单餐品建议（无AI）
    private func generateSimpleMealSuggestion() -> MealSuggestion? {
        guard let context = modelContext else { return nil }
        
        do {
            let foodGroups = try context.fetch(FetchDescriptor<FoodGroup>())
            let allItems = foodGroups.flatMap { $0.items }
            
            if allItems.isEmpty {
                return nil
            }
            
            // 检查即将过期的食材
            let now = Date()
            let threeDaysLater = Calendar.current.date(byAdding: .day, value: 3, to: now)!
            
            let expiringItems = allItems.filter { item in
                guard let expirationDate = item.expirationDate else { return false }
                return expirationDate <= threeDaysLater && expirationDate >= now
            }
            
            let currentMealType = MealType.getCurrentMealType()
            let targetItems = expiringItems.isEmpty ? Array(allItems.prefix(3)) : expiringItems
            
            return MealSuggestion(
                dishName: "简单家常菜",
                reason: expiringItems.isEmpty ? "optimal.meal.suggestion".localized : "priority.expiring.ingredients".localized,
                cookingTime: 25,
                difficulty: .easy,
                suitability: "family.suitable".localized,
                ingredients: targetItems.map { $0.name },
                urgency: expiringItems.isEmpty ? .normal : .high,
                mealType: currentMealType,
                nutritionHighlights: ["nutrition.highlight.balanced".localized, "nutrition.highlight.homestyle".localized],
                recipePreview: "用现有食材制作的美味料理"
            )
        } catch {
            return nil
        }
    }
    
    /// 生成简单生活小贴士（无AI）
    private func generateSimpleLifeTips() -> [LifeTip] {
        var tips: [LifeTip] = []
        
        // 添加基于时间的贴士
        tips.append(generateTimeBasedTip())
        
        // 添加基于天气的贴士
        Task {
            if let weatherTip = await generateWeatherBasedTip() {
                tips.append(weatherTip)
            }
        }
        
        // 移除了鼓励性贴士功能
        
        return tips.filter { $0.isRelevant }
    }
    
    // MARK: - Private Methods
    
    
    private func generateWeatherInfo() async -> WeatherInfo? {
        // 使用重构后的WeatherKitService，它已经有内置的超时机制
        return await weatherKitService.getCurrentWeather()
    }
    
    private func calculateDailyCalorieNeeds() async -> Double {
        guard let context = modelContext else { return 2000 }
        
        do {
            let familyProfiles = try context.fetch(FetchDescriptor<FamilyProfile>())
            guard let familyProfile = familyProfiles.first else { return 2000 }
            
            return familyProfile.totalDailyCalories
        } catch {
            print("Error calculating daily calorie needs: \\(error)")
            return 2000
        }
    }
    
    private func generateInventorySnapshot() async -> InventorySnapshot {
        guard let context = modelContext else {
            return InventorySnapshot()
        }
        
        do {
            let foodGroups = try context.fetch(FetchDescriptor<FoodGroup>())
            let allItems = foodGroups.flatMap { $0.items }
            
            // 获取即将过期的食材（3天内）
            let now = Date()
            let threeDaysLater = Calendar.current.date(byAdding: .day, value: 3, to: now)!
            
            let expiringItems = allItems.filter { item in
                guard let expirationDate = item.expirationDate else { return false }
                return expirationDate <= threeDaysLater && expirationDate >= now
            }
            
            // 确定库存水平
            let stockLevel: StockLevel
            if allItems.isEmpty {
                stockLevel = .empty
            } else if allItems.count < 10 {
                stockLevel = .low
            } else if allItems.count < 30 {
                stockLevel = .sufficient
            } else {
                stockLevel = .abundant
            }
            
            // 生成状态描述
            let statusDescription = generateInventoryStatusDescription(
                totalItems: allItems.count,
                expiringCount: expiringItems.count,
                stockLevel: stockLevel
            )
            
            return InventorySnapshot(
                totalItems: allItems.count,
                expiringItems: expiringItems,
                statusDescription: statusDescription,
                stockLevel: stockLevel,
                nutritionInsight: generateNutritionInsight(from: allItems)
            )
        } catch {
            print("Error generating inventory snapshot: \\(error)")
            return InventorySnapshot()
        }
    }
    
    private func generateInventoryStatusDescription(totalItems: Int, expiringCount: Int, stockLevel: StockLevel) -> String {
        if totalItems == 0 {
            return "inventory.empty.description".localized
        }
        
        let baseDescription = String(format: "inventory.items.count".localized, totalItems)
        
        if expiringCount > 0 {
            return "\(baseDescription)，\(String(format: "inventory.expiring.warning".localized, expiringCount))"
        } else {
            return "\(baseDescription)，\(stockLevel.localizedName)"
        }
    }
    
    private func generateNutritionInsight(from items: [FoodItem]) -> String {
        if items.isEmpty {
            return "nutrition.empty.tip".localized
        }
        
        // 简单的营养洞察逻辑
        let categories = items.compactMap { $0.category }.map { $0.rawValue }
        let categoryCount = Set(categories).count
        
        if categoryCount >= 5 {
            return "nutrition.diverse.good".localized
        } else if categoryCount >= 3 {
            return "nutrition.balanced.ok".localized
        } else {
            return "nutrition.need.diversity".localized
        }
    }
    
    private func generateMealSuggestion() async -> MealSuggestion? {
        guard let context = modelContext else { return nil }
        
        do {
            let foodGroups = try context.fetch(FetchDescriptor<FoodGroup>())
            let allItems = foodGroups.flatMap { $0.items }
            
            if allItems.isEmpty {
                return nil
            }
            
            // 获取当前天气
            let weather = await generateWeatherInfo()
            
            // 使用主页专用的简化XML推荐系统
            return await generateSimpleWeatherMoodSuggestionWithAI(weather: weather)
        } catch {
            print("Error generating meal suggestion: \\(error)")
            return nil
        }
    }
    
    private func generateSimpleWeatherMoodSuggestionWithAI(weather: WeatherInfo?) async -> MealSuggestion? {
        // 如果没有心情信息，不生成AI推荐
        guard currentMood != nil else {
            print("DEBUG: 没有心情信息，跳过AI推荐生成")
            // 确保加载状态为false
            await MainActor.run {
                isMealSuggestionLoading = false
            }
            return nil
        }
        
        // 设置加载状态
        await MainActor.run {
            isMealSuggestionLoading = true
        }
        
        do {
            let systemPrompt: String
            
            if let weather = weather {
                // 有天气信息，使用天气+心情推荐
                systemPrompt = homePagePrompts.buildWeatherMoodRecommendationPrompt(weather: weather, mood: currentMood, recentDishes: recentDishNames)
            } else {
                // 没有天气信息，使用心情+时间fallback推荐
                systemPrompt = homePagePrompts.buildMoodTimeRecommendationPrompt(mood: currentMood, recentDishes: recentDishNames)
            }
            
            let userMessage = homePagePrompts.buildSimpleUserMessage()
            
            let response = try await aiService.simpleTextGeneration(
                message: userMessage,
                systemPrompt: systemPrompt
            )
            
            // 解析简化XML格式的响应
            if let parsedSuggestion = parseSimpleXMLResponse(response) {
                // 重置失败状态
                lastAiGenerationFailed = false
                isDailyLimitExceeded = false
                // 更新最近推荐的菜品列表
                updateRecentDishNames(parsedSuggestion.dishName)
                // 清除加载状态
                await MainActor.run {
                    isMealSuggestionLoading = false
                }
                return parsedSuggestion
            } else {
                // 解析失败，记录错误状态
                print("XML解析失败，标记为AI生成失败")
                lastAiGenerationFailed = true
                // 清除加载状态
                await MainActor.run {
                    isMealSuggestionLoading = false
                }
                return nil
            }
        } catch {
            print("Error generating contextual meal suggestion: \(error)")
            
            // 检查是否是每日限额错误
            if let aiError = error as? AIServiceError {
                switch aiError {
                case .dailyLimitExceeded:
                    // 记录为每日限额错误状态
                    lastAiGenerationFailed = true
                    isDailyLimitExceeded = true
                    print("DEBUG: 达到每日AI限额")
                default:
                    // 其他AI调用失败，记录失败状态
                    lastAiGenerationFailed = true
                    isDailyLimitExceeded = false
                }
            } else {
                // 非AI服务错误，记录失败状态
                lastAiGenerationFailed = true
                isDailyLimitExceeded = false
            }
            
            // 清除加载状态
            await MainActor.run {
                isMealSuggestionLoading = false
            }
            return nil
        }
    }
    
    
    // 移除了旧的库存依赖的膳食建议生成方法，现在使用统一的XML推荐系统
    
    private func generateShoppingStatus() async -> ShoppingStatus {
        guard let context = modelContext else {
            return ShoppingStatus()
        }
        
        do {
            let shoppingItems = try context.fetch(FetchDescriptor<ShoppingListItem>())
            let urgentItems = shoppingItems.filter { $0.isUrgent }.map { $0.name }
            let estimatedCost = shoppingItems.reduce(0) { $0 + ($1.estimatedPrice ?? 0) }
            
            return ShoppingStatus(
                itemCount: shoppingItems.count,
                urgentItems: urgentItems,
                estimatedCost: estimatedCost,
                hasShortageItems: !urgentItems.isEmpty
            )
        } catch {
            print("Error generating shopping status: \\(error)")
            return ShoppingStatus()
        }
    }
    
    // 移除了生活贴士生成功能
    
    // 移除了鼓励功能相关方法
    
    private func getTipIcon(for type: LifeTipType) -> String {
        switch type {
        case .weatherBasedSuggestion:
            return "cloud.sun.fill"
        case .timeBasedSuggestion:
            return "clock.fill"
        case .encouragement:
            return "heart.fill" // 保留图标定义但移除相关功能
        case .nutritionTip:
            return "leaf.fill"
        case .general:
            return "lightbulb.fill"
        }
    }
    
    private func generateTimeBasedTip() -> LifeTip {
        let isWeekday = !Calendar.current.isDateInWeekend(Date())
        let hour = Calendar.current.component(.hour, from: Date())
        
        if isWeekday && hour >= 17 && hour <= 20 {
            return LifeTip(
                icon: "clock.fill",
                message: "weekday.evening.tip".localized,
                type: .timeBasedSuggestion
            )
        } else if !isWeekday && hour >= 10 && hour <= 14 {
            return LifeTip(
                icon: "sun.max.fill",
                message: "weekend.brunch.tip".localized,
                type: .timeBasedSuggestion
            )
        }
        
        return LifeTip.empty
    }
    
    private func generateWeatherBasedTip() async -> LifeTip? {
        guard let weather = await generateWeatherInfo() else {
            return nil
        }
        
        switch weather.condition {
        case .sunny:
            return LifeTip(
                icon: "leaf.fill",
                message: "sunny.day.tip".localized,
                type: .weatherBasedSuggestion
            )
        case .rainy:
            return LifeTip(
                icon: "cloud.rain.fill",
                message: "rainy.day.tip".localized,
                type: .weatherBasedSuggestion
            )
        case .cold:
            return LifeTip(
                icon: "thermometer.snowflake",
                message: "cold.day.tip".localized,
                type: .weatherBasedSuggestion
            )
        default:
            return nil
        }
    }
    
    // 移除了鼓励功能相关方法
    
    // MARK: - XML Recommendation Methods
    
    // 移除了旧的复杂XML提示词系统，现在使用HomePagePrompts中的简化系统
    
    // 移除了旧的buildSimpleUserMessage方法，现在使用HomePagePrompts中的统一方法
    
    // MARK: - Simple XML Parsing Methods
    
    private func parseSimpleXMLResponse(_ response: String) -> MealSuggestion? {
        // 尝试提取简化的XML内容
        guard let xmlStart = response.range(of: "<Recommendation>"),
              let xmlEnd = response.range(of: "</Recommendation>") else {
            return nil
        }
        
        let xmlContent = String(response[xmlStart.upperBound..<xmlEnd.lowerBound])
        
        // 提取各个字段
        let dishName = extractXMLValue(from: xmlContent, tag: "DishName") ?? "recommended.dish".localized
        let reason = extractXMLValue(from: xmlContent, tag: "RecommendationReason") ?? ""
        let tips = extractXMLValue(from: xmlContent, tag: "CookingTips") ?? ""
        let warmMessage = extractXMLValue(from: xmlContent, tag: "WarmMessage") ?? ""
        let ingredientsString = extractXMLValue(from: xmlContent, tag: "Ingredients") ?? ""
        let cookingStepsString = extractXMLValue(from: xmlContent, tag: "CookingSteps") ?? ""
        let cookingTimeString = extractXMLValue(from: xmlContent, tag: "CookingTime") ?? ""
        let nutritionString = extractXMLValue(from: xmlContent, tag: "Nutrition") ?? ""
        
        // 解析食材列表（保留完整的"食材名 数量单位"格式）
        let ingredients = ingredientsString
            .components(separatedBy: ",")
            .map { ingredient in
                ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        
        // 解析营养信息为结构化数据
        let nutritionData = parseNutritionData(from: nutritionString)
        
        // 解析制作步骤（支持中英文分号）
        let cookingSteps = parseStepsFromString(cookingStepsString)
        
        // 解析烹饪时间
        let cookingTime = parseCookingTime(from: cookingTimeString)
        
        // 解析营养高亮（从营养字符串中提取关键词作为高亮）
        let nutritionHighlights = extractNutritionHighlights(from: nutritionString)
        
        // 组合简洁的描述
        var fullDescription = reason
        if !tips.isEmpty {
            fullDescription += "\n💡 " + tips
        }
        if !warmMessage.isEmpty {
            fullDescription += "\n💝 " + warmMessage
        }
        
        // 构建制作步骤的预览文本
        let recipePreview = cookingStepsString.isEmpty ? "" : cookingStepsString.replacingOccurrences(of: ";", with: "\n")
        
        let mealSuggestion = MealSuggestion(
            dishName: dishName,
            reason: fullDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            cookingTime: cookingTime,
            difficulty: .easy,
            suitability: "family.suitable".localized,
            ingredients: ingredients,
            urgency: .normal,
            mealType: MealType.getCurrentMealType(),
            nutritionHighlights: nutritionHighlights,
            recipePreview: recipePreview,
            cookingSteps: cookingSteps,
            nutritionData: nutritionData
        )
        
        
        return mealSuggestion
    }
    
    // 移除了旧的复杂XML提示词系统，现在使用HomePagePrompts中的简化系统
    
    private func extractXMLValue(from content: String, tag: String) -> String? {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) else {
            return nil
        }
        
        if let range = Range(match.range(at: 1), in: content) {
            return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    /// 更新最近推荐的菜品列表
    private func updateRecentDishNames(_ dishName: String) {
        // 添加新菜品到列表开头
        recentDishNames.insert(dishName, at: 0)
        
        // 移除重复项
        recentDishNames = Array(OrderedSet(recentDishNames))
        
        // 限制列表长度
        if recentDishNames.count > maxRecentDishes {
            recentDishNames = Array(recentDishNames.prefix(maxRecentDishes))
        }
        
    }
    
    /// 解析营养数据字符串为结构化数据
    private func parseNutritionData(from nutritionString: String) -> NutritionData? {
        guard !nutritionString.isEmpty else { return nil }
        
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var calories: Double = 0
        
        let components = nutritionString.components(separatedBy: ",")
        
        // 首先尝试关键词匹配格式（中文格式："蛋白质 25g"）
        var foundKeywordMatch = false
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 尝试匹配各种营养成分格式
            if trimmed.contains("蛋白质") || trimmed.lowercased().contains("protein") {
                protein = extractNutritionValue(from: trimmed)
                foundKeywordMatch = true
            } else if trimmed.contains("碳水化合物") || trimmed.lowercased().contains("carb") {
                carbs = extractNutritionValue(from: trimmed)
                foundKeywordMatch = true
            } else if trimmed.contains("脂肪") || trimmed.lowercased().contains("fat") {
                fat = extractNutritionValue(from: trimmed)
                foundKeywordMatch = true
            } else if trimmed.contains("纤维") || trimmed.lowercased().contains("fiber") {
                fiber = extractNutritionValue(from: trimmed)
                foundKeywordMatch = true
            } else if trimmed.contains("热量") || trimmed.lowercased().contains("calorie") {
                calories = extractNutritionValue(from: trimmed)
                foundKeywordMatch = true
            }
        }
        
        // 如果没有找到关键词匹配，尝试顺序格式（英文格式："30g,40g,10g,350Kcal"）
        if !foundKeywordMatch && components.count >= 4 {
            let trimmedComponents = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // 按照顺序解析：蛋白质、碳水化合物、脂肪、热量
            if trimmedComponents.count >= 4 {
                protein = extractNutritionValue(from: trimmedComponents[0])
                carbs = extractNutritionValue(from: trimmedComponents[1])
                fat = extractNutritionValue(from: trimmedComponents[2])
                calories = extractNutritionValue(from: trimmedComponents[3])
            }
        }
        
        return NutritionData(protein: protein, carbs: carbs, fat: fat, fiber: fiber, calories: calories)
    }
    
    /// 从字符串中提取数值
    private func extractNutritionValue(from text: String) -> Double {
        // 使用正则表达式提取数字
        let pattern = #"(\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return 0
        }
        
        return Double(String(text[range])) ?? 0
    }
    
    /// 从营养字符串中提取营养高亮关键词
    private func extractNutritionHighlights(from nutritionString: String) -> [String] {
        guard !nutritionString.isEmpty else { return [] }
        
        var highlights: [String] = []
        
        let components = nutritionString.components(separatedBy: ",")
        
        // 首先尝试关键词匹配格式
        var foundKeywordMatch = false
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 提取营养成分名称作为高亮
            if trimmed.contains("蛋白质") || trimmed.lowercased().contains("protein") {
                highlights.append("nutrition.highlight.high_protein".localized)
                foundKeywordMatch = true
            } else if trimmed.contains("碳水化合物") || trimmed.lowercased().contains("carb") {
                highlights.append("nutrition.highlight.carbs".localized)
                foundKeywordMatch = true
            } else if trimmed.contains("脂肪") || trimmed.lowercased().contains("fat") {
                highlights.append("nutrition.highlight.healthy_fat".localized)
                foundKeywordMatch = true
            } else if trimmed.contains("纤维") || trimmed.lowercased().contains("fiber") {
                highlights.append("nutrition.highlight.high_fiber".localized)
                foundKeywordMatch = true
            } else if trimmed.contains("热量") || trimmed.lowercased().contains("calorie") {
                let calories = extractNutritionValue(from: trimmed)
                if calories < 300 {
                    highlights.append("nutrition.highlight.low_calorie".localized)
                } else if calories > 500 {
                    highlights.append("nutrition.highlight.high_energy".localized)
                }
                foundKeywordMatch = true
            }
        }
        
        // 如果没有找到关键词匹配，尝试顺序格式解析
        if !foundKeywordMatch && components.count >= 4 {
            let trimmedComponents = components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            // 按照顺序解析：蛋白质、碳水化合物、脂肪、热量
            if trimmedComponents.count >= 4 {
                let protein = extractNutritionValue(from: trimmedComponents[0])
                let carbs = extractNutritionValue(from: trimmedComponents[1])
                let fat = extractNutritionValue(from: trimmedComponents[2])
                let calories = extractNutritionValue(from: trimmedComponents[3])
                
                // 根据数值生成亮点
                if protein > 20 {
                    highlights.append("nutrition.highlight.high_protein".localized)
                }
                if carbs > 30 {
                    highlights.append("nutrition.highlight.carbs".localized)
                }
                if fat > 0 && fat < 15 {
                    highlights.append("nutrition.highlight.healthy_fat".localized)
                }
                if calories < 300 {
                    highlights.append("nutrition.highlight.low_calorie".localized)
                } else if calories > 500 {
                    highlights.append("nutrition.highlight.high_energy".localized)
                }
            }
        }
        
        return highlights.isEmpty ? ["nutrition.highlight.balanced".localized] : highlights
    }
    
    /// 解析烹饪时间字符串，提取分钟数
    private func parseCookingTime(from cookingTimeString: String) -> Int {
        guard !cookingTimeString.isEmpty else { 
            return 25 // 默认25分钟
        }
        
        // 提取数字部分
        let numericString = cookingTimeString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let time = Int(numericString), time > 0 && time <= 240 { // 限制在合理范围内（1-240分钟）
            return time
        }
        
        return 25 // 如果解析失败，返回默认值
    }
    
    /// 解析制作步骤字符串，支持多种分隔符
    private func parseStepsFromString(_ stepsString: String) -> [String] {
        guard !stepsString.isEmpty else { 
            return [] 
        }
        
        var steps: [String] = []
        
        // 尝试不同的分隔符
        let separators = [";", "；", "\n", "。"] // 英文分号、中文分号、换行、句号
        
        for separator in separators {
            let components = stepsString.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            if components.count > 1 {
                steps = components
                break
            }
        }
        
        // 如果没有找到合适的分隔符，尝试按数字编号分割
        if steps.isEmpty {
            steps = parseStepsByNumbering(stepsString)
        }
        
        // 如果还是没有步骤，就把整个字符串作为一个步骤
        if steps.isEmpty && !stepsString.isEmpty {
            steps = [stepsString]
        }
        
        // 清理步骤文本，移除编号
        return steps.map { cleanStepText($0) }
    }
    
    /// 按照数字编号分割步骤
    private func parseStepsByNumbering(_ text: String) -> [String] {
        // 使用正则表达式匹配 "1. ", "2. ", "3. " 等格式
        let pattern = #"(\d+\.\s*)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        if matches.count > 1 {
            var steps: [String] = []
            
            for i in 0..<matches.count {
                let startIndex = matches[i].range.upperBound
                let endIndex = i + 1 < matches.count ? matches[i + 1].range.lowerBound : text.count
                
                if let startRange = Range(NSRange(location: startIndex, length: endIndex - startIndex), in: text) {
                    let stepContent = String(text[startRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !stepContent.isEmpty {
                        steps.append(stepContent)
                    }
                }
            }
            
            return steps
        }
        
        return []
    }
    
    /// 清理步骤文本，移除开头的编号
    private func cleanStepText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除开头的数字编号模式，如 "1. ", "2. ", "步骤1：" 等
        let patterns = [
            #"^\d+\.\s*"#,           // "1. "
            #"^第\d+步[:：]\s*"#,      // "第1步："
            #"^步骤\d+[:：]\s*"#,      // "步骤1："
            #"^\d+[:：]\s*"#          // "1："
        ]
        
        var cleanedText = trimmed
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: cleanedText, range: NSRange(cleanedText.startIndex..., in: cleanedText)) {
                if let range = Range(match.range, in: cleanedText) {
                    cleanedText = String(cleanedText[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        
        return cleanedText.isEmpty ? trimmed : cleanedText
    }
    
    /// 检查是否是今天第一次启动
    private func isFirstLaunchToday() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let lastLaunchKey = "lastLaunchDate"
        
        if let lastLaunchDate = UserDefaults.standard.object(forKey: lastLaunchKey) as? Date {
            let lastLaunchDay = Calendar.current.startOfDay(for: lastLaunchDate)
            let isFirstToday = today > lastLaunchDay
            
            if isFirstToday {
                UserDefaults.standard.set(Date(), forKey: lastLaunchKey)
            }
            
            return isFirstToday
        } else {
            // 第一次安装
            UserDefaults.standard.set(Date(), forKey: lastLaunchKey)
            return true
        }
    }
    
    // MARK: - Mood Status Management
    
    /// 检查心情状态
    private func checkMoodStatus() {
        // 从UserDefaults加载心情状态
        loadMoodStatusFromUserDefaults()
        
        // 检查是否需要提醒用户选择心情
        updateMoodPromptStatus()
    }
    
    /// 设置心情状态检查定时器
    private func setupMoodStatusTimer() {
        // 每30分钟检查一次心情状态
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMoodPromptStatus()
            }
        }
    }
    
    /// 更新心情提醒状态
    func updateMoodPromptStatus() {
        // 如果从未设置心情，应该提醒
        guard let lastUpdate = lastMoodUpdateTime else {
            shouldPromptMoodSelection = true
            // 确保加载状态为false（没有心情，不应该显示加载状态）
            isMealSuggestionLoading = false
            print("DEBUG: 从未设置心情，需要提醒用户选择")
            return
        }
        
        // 检查是否超过6小时
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        if timeSinceLastUpdate >= moodExpirationInterval {
            shouldPromptMoodSelection = true
            // 心情过期时清除当前心情状态，让用户重新选择
            currentMood = nil
            lastMoodUpdateTime = nil
            // 确保加载状态为false（心情过期，不应该显示加载状态）
            isMealSuggestionLoading = false
            // 不清除AI缓存，保留上次的推荐直到用户手动选择新心情
            // 清除UserDefaults中的过期数据
            UserDefaults.standard.removeObject(forKey: "userMoodType")
            UserDefaults.standard.removeObject(forKey: "lastMoodUpdateTime")
            print("DEBUG: 心情已过期(\(Int(timeSinceLastUpdate/3600))小时)，已清除心情状态，需要提醒用户重新选择")
        } else {
            shouldPromptMoodSelection = false
            // 确保加载状态为false（心情有效，不需要重新生成）
            isMealSuggestionLoading = false
        }
    }
    
    /// 保存心情状态到UserDefaults
    private func saveMoodStatusToUserDefaults() {
        if let mood = currentMood {
            UserDefaults.standard.set(mood.mood.rawValue, forKey: "userMoodType")
        }
        
        if let lastUpdate = lastMoodUpdateTime {
            UserDefaults.standard.set(lastUpdate, forKey: "lastMoodUpdateTime")
        }
    }
    
    /// 从UserDefaults加载心情状态
    private func loadMoodStatusFromUserDefaults() {
        // 加载心情类型
        if let moodRawValue = UserDefaults.standard.object(forKey: "userMoodType") as? String,
           let moodType = MoodType(rawValue: moodRawValue) {
            currentMood = UserMood(mood: moodType)
        }
        
        // 加载最后更新时间
        if let lastUpdate = UserDefaults.standard.object(forKey: "lastMoodUpdateTime") as? Date {
            lastMoodUpdateTime = lastUpdate
        }
        
        // 加载缓存的餐品推荐
        loadMealSuggestionCache()
    }
    
    /// 从UserDefaults加载餐品推荐缓存
    private func loadMealSuggestionCache() {
        // 加载餐品推荐数据
        if let cachedData = UserDefaults.standard.data(forKey: "cachedMealSuggestion"),
           let suggestion = try? JSONDecoder().decode(MealSuggestion.self, from: cachedData) {
            cachedMealSuggestion = suggestion
        }
        
        // 加载AI生成时间
        if let lastGenTime = UserDefaults.standard.object(forKey: "lastAiGenerationTime") as? Date {
            lastAiGenerationTime = lastGenTime
        }
        
        // 加载生成时的心情
        if let moodRawValue = UserDefaults.standard.object(forKey: "lastMoodForAiGeneration") as? String,
           let moodType = MoodType(rawValue: moodRawValue) {
            lastMoodForAiGeneration = UserMood(mood: moodType)
        }
    }
    
    /// 保存餐品推荐缓存到UserDefaults
    private func saveMealSuggestionCache() {
        // 保存餐品推荐数据
        if let suggestion = cachedMealSuggestion,
           let data = try? JSONEncoder().encode(suggestion) {
            UserDefaults.standard.set(data, forKey: "cachedMealSuggestion")
        }
        
        // 保存AI生成时间
        if let lastGenTime = lastAiGenerationTime {
            UserDefaults.standard.set(lastGenTime, forKey: "lastAiGenerationTime")
        }
        
        // 保存生成时的心情
        if let mood = lastMoodForAiGeneration {
            UserDefaults.standard.set(mood.mood.rawValue, forKey: "lastMoodForAiGeneration")
        }
    }
    
    /// 手动触发心情提醒
    func triggerMoodPrompt() {
        shouldPromptMoodSelection = true
    }
    
    /// 获取心情剩余有效时间（小时）
    func getMoodRemainingHours() -> Int {
        guard let lastUpdate = lastMoodUpdateTime else { return 0 }
        
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        let remainingTime = moodExpirationInterval - timeSinceUpdate
        
        return max(0, Int(remainingTime / 3600))
    }
    
    /// 清除所有状态和缓存（包括心情状态）- 用于数据重置
    func clearAllStateAndCache() {
        print("🗑️ HomeStatusService: Clearing all state and cache...")
        
        // 清除心情状态
        currentMood = nil
        lastMoodUpdateTime = nil
        shouldPromptMoodSelection = true
        
        // 清除所有缓存
        clearCache()
        
        // 清除AI服务缓存
        Task {
            await AIService.shared.clearCache()
        }
        
        // 清除UserDefaults中的心情相关数据
        UserDefaults.standard.removeObject(forKey: "userMoodType")
        UserDefaults.standard.removeObject(forKey: "lastMoodUpdateTime")
        
        // 清除其他与用户数据和记忆相关的UserDefaults数据
        UserDefaults.standard.removeObject(forKey: "hasShownWelcome")
        UserDefaults.standard.removeObject(forKey: "lastWeatherUpdate")
        UserDefaults.standard.removeObject(forKey: "lastLaunchDate") // 确保重置后被视为首次启动
        UserDefaults.standard.removeObject(forKey: "lastAppLaunch_mood")
        UserDefaults.standard.removeObject(forKey: "lastAppLaunch_weather")
        UserDefaults.standard.removeObject(forKey: "lastAppLaunch_ai")
        
        // 注意：保留用户偏好设置（主题、AI模型选择、通知设置等）
        
        print("✅ HomeStatusService: All state and cache cleared")
    }
}

// MARK: - OrderedSet helper for maintaining unique order
private struct OrderedSet<T: Hashable>: Sequence {
    private var array: [T] = []
    private var set: Set<T> = []
    
    init<S: Sequence>(_ sequence: S) where S.Element == T {
        for element in sequence {
            append(element)
        }
    }
    
    mutating func append(_ element: T) {
        if !set.contains(element) {
            array.append(element)
            set.insert(element)
        }
    }
    
    func makeIterator() -> Array<T>.Iterator {
        return array.makeIterator()
    }
}

