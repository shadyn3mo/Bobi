import SwiftUI

struct SmartRecipeButtonsGrid: View {
    @ObservedObject var viewModel: RecipeViewModel
    @StateObject private var dailyUsageManager = DailyUsageManager.shared
    let foodGroups: [FoodGroup]
    
    @State private var showingQuotaExceededAlert = false
    @State private var quotaExceededMessage = ""
    
    var hasBabies: Bool {
        viewModel.familyMembers.contains { $0.ageCategory == .baby }
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
    
    var seasonalTitle: String {
        switch currentSeason {
        case .spring:
            return "recipe.seasonal.spring".localized
        case .summer:
            return "recipe.seasonal.summer".localized
        case .autumn:
            return "recipe.seasonal.autumn".localized
        case .winter:
            return "recipe.seasonal.winter".localized
        }
    }
    
    var seasonalSubtitle: String {
        switch currentSeason {
        case .spring:
            return "recipe.seasonal.spring.subtitle".localized
        case .summer:
            return "recipe.seasonal.summer.subtitle".localized
        case .autumn:
            return "recipe.seasonal.autumn.subtitle".localized
        case .winter:
            return "recipe.seasonal.winter.subtitle".localized
        }
    }
    
    var seasonalIcon: String {
        switch currentSeason {
        case .spring:
            return "leaf.fill"
        case .summer:
            return "sun.max.fill"
        case .autumn:
            return "leaf.circle.fill"
        case .winter:
            return "snowflake"
        }
    }
    
    var seasonalColor: Color {
        switch currentSeason {
        case .spring:
            return .green
        case .summer:
            return .yellow
        case .autumn:
            return .orange
        case .winter:
            return .blue
        }
    }
    
    var seasonalMessage: String {
        switch currentSeason {
        case .spring:
            return "recipe.seasonal.spring.message".localized
        case .summer:
            return "recipe.seasonal.summer.message".localized
        case .autumn:
            return "recipe.seasonal.autumn.message".localized
        case .winter:
            return "recipe.seasonal.winter.message".localized
        }
    }
    
    // 检查是否可以使用AI，如果是免费模式且配额用完则显示提示
    private func checkAIUsageAndProceed(with message: String, buttonId: String) {
        // 检查是否为免费模式且配额用完
        if !dailyUsageManager.canUseAI() {
            let aiModelManager = AIModelManager.shared
            if !(aiModelManager.apiSource == .custom && !aiModelManager.currentAPIKey.isEmpty) {
                // 免费模式且配额用完，显示弹窗提示
                quotaExceededMessage = "ai.error.daily.limit.exceeded".localized + "\n\n" + 
                                     "ai.upgrade.tip.description".localized
                showingQuotaExceededAlert = true
                return
            }
        }
        
        // 配额检查通过，发送消息
        viewModel.sendQuickMessage(message, buttonId: buttonId)
    }
    
    var babyFoodTitle: String {
        if hasBabies {
            let babiesWithStages = viewModel.familyMembers.filter { $0.age == 0 && $0.monthsForBaby > 0 }
            if let baby = babiesWithStages.first, let stage = baby.babyFoodStage {
                switch stage {
                case .stage1:
                    return "baby.food.stage1.title".localized
                case .stage2:
                    return "baby.food.stage2.title".localized
                }
            } else {
                return "recipe.baby.food".localized
            }
        } else {
            return "recipe.soft.easy".localized
        }
    }
    
    var babyFoodSubtitle: String {
        if hasBabies {
            let babiesWithStages = viewModel.familyMembers.filter { $0.age == 0 && $0.monthsForBaby > 0 }
            if let baby = babiesWithStages.first, let stage = baby.babyFoodStage {
                switch stage {
                case .stage1:
                    return "baby.food.stage1.subtitle".localized
                case .stage2:
                    return "baby.food.stage2.subtitle".localized
                }
            } else {
                return "recipe.soft.nutritious".localized
            }
        } else {
            return "recipe.gentle.digestible".localized
        }
    }
    
    var babyFoodMessage: String {
        if hasBabies {
            let babiesWithStages = viewModel.familyMembers.filter { $0.age == 0 && $0.monthsForBaby > 0 }
            if let baby = babiesWithStages.first, let stage = baby.babyFoodStage {
                switch stage {
                case .stage1:
                    return "baby.food.stage1.message".localized
                case .stage2:
                    return "baby.food.stage2.message".localized
                }
            } else {
                return "baby.food.general.message".localized
            }
        } else {
            return "recipe.soft.texture.message".localized
        }
    }
    
    var body: some View {
        Group {
            SmartRecipeButton(
                title: "recipe.tonight.dinner".localized,
                subtitle: "recipe.balanced.nutrition".localized,
                icon: "moon.stars.fill",
                color: .indigo,
                isDisabled: viewModel.isLoading,
                isLoading: viewModel.loadingButtonId == "tonight_dinner",
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    // 检查是否有即将过期的食材
                    let expiringItems = foodGroups.flatMap { $0.items }
                        .filter { item in
                            if let days = item.daysUntilExpiration {
                                return days <= 3 && days >= 0
                            }
                            return false
                        }
                    
                    let baseVariations = viewModel.isEnglishMode ? [
                        "Design a wholesome and satisfying family dinner, balancing protein, carbs, and vegetables.",
                        "Suggest a comforting, classic home-style meal that everyone from kids to adults will enjoy.",
                        "Create a nutritious main course and a complementary side dish suitable for a weeknight family dinner.",
                        "Recommend a flavorful, easy-to-follow dinner recipe that brings a sense of warmth and togetherness."
                    ] : [
                        "设计一份营养全面的家庭晚餐，均衡搭配蛋白质、碳水和蔬菜。",
                        "来一份温馨的家常经典菜，要能同时满足孩子和成年人的口味。",
                        "为工作日晚餐创作一道主菜和一道搭配的副菜，要求健康又美味。",
                        "推荐一个有滋有味又容易上手的晚餐食谱，能营造出温暖的家庭氛围。"
                    ]
                    
                    var message = baseVariations[Int(Date().timeIntervalSince1970) % baseVariations.count]
                    
                    // 如果有即将过期的食材，在提示词中添加优先使用的建议
                    if !expiringItems.isEmpty {
                        let expiringNames = expiringItems.map { $0.name }.joined(separator: viewModel.isEnglishMode ? ", " : "、")
                        let priorityNote = viewModel.isEnglishMode
                            ? " If possible, please prioritize using these ingredients that are expiring soon: \(expiringNames)."
                            : " 如果可能的话，请优先使用这些即将过期的食材：\(expiringNames)。"
                        message += priorityNote
                    }
                    
                    checkAIUsageAndProceed(with: message, buttonId: "tonight_dinner")
                }
            }
            
            SmartRecipeButton(
                title: "recipe.healthy.meal".localized,
                subtitle: "recipe.low.fat.high.protein".localized,
                icon: "heart.fill",
                color: .pink,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let variations = viewModel.isEnglishMode ? [
                        "Create a nutrient-dense meal focused on lean protein, complex carbs, and healthy fats.",
                        "Design a dish rich in antioxidants and vitamins, using a variety of colorful vegetables.",
                        "Design a gentle, easy-to-digest healthy meal, rich in dietary fiber to promote gut health.",
                        "Recommend a 'clean eating' meal, emphasizing whole foods and minimizing processed ingredients."
                    ] : [
                        "创作一份营养密度高的美食，侧重于瘦蛋白、复合碳水和健康脂肪。",
                        "设计一道富含抗氧化剂和维生素的菜品，食材要尽可能色彩丰富。",
                        "设计一道温和、易于消化的健康餐，富含膳食纤维来促进肠道健康。",
                        "建议一份'清洁饮食'餐，强调使用完整食物，并尽量减少加工成分。"
                    ]
                    let message = variations[Int(Date().timeIntervalSince1970) % variations.count]
                    checkAIUsageAndProceed(with: message, buttonId: "healthy_meal")
                }
            }
            
            SmartRecipeButton(
                title: "recipe.quick.cook".localized,
                subtitle: "recipe.under.30min".localized,
                icon: "timer.circle.fill",
                color: .orange,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    // 检查是否有即将过期的食材
                    let expiringItems = foodGroups.flatMap { $0.items }
                        .filter { item in
                            if let days = item.daysUntilExpiration {
                                return days <= 3 && days >= 0
                            }
                            return false
                        }
                    
                    let baseVariations = viewModel.isEnglishMode ? [
                        "I need a complete meal ready in under 20 minutes, from prep to plate.",
                        "Design a flavorful one-pan or one-pot recipe that minimizes cleanup.",
                        "Suggest a delicious, no-fuss meal with 2 main ingredients or less.",
                        "Give me a quick-assembly recipe, like a wrap or power bowl, that requires minimal cooking."
                    ] : [
                        "我需要一个从备菜到上桌，全程不超过20分钟的完整餐食。",
                        "设计一个美味的'一锅出'食谱，能最大程度地减少清洗工作。",
                        "推荐一道用不超过2种主要食材就能搞定的快手美食。",
                        "给我一个几乎不用开火的快装食谱，比如卷饼或者能量碗。"
                    ]
                    
                    var message = baseVariations[Int(Date().timeIntervalSince1970) % baseVariations.count]
                    
                    // 如果有即将过期的食材，在提示词中添加优先使用的建议
                    if !expiringItems.isEmpty {
                        let expiringNames = expiringItems.map { $0.name }.joined(separator: viewModel.isEnglishMode ? ", " : "、")
                        let priorityNote = viewModel.isEnglishMode
                            ? " Try to incorporate these expiring ingredients if suitable for quick cooking: \(expiringNames)."
                            : " 如果适合快速烹饪，请尝试加入这些即将过期的食材：\(expiringNames)。"
                        message += priorityNote
                    }
                    
                    checkAIUsageAndProceed(with: message, buttonId: "quick_cook")
                }
            }
            
            SmartRecipeButton(
                title: "recipe.use.expiring".localized,
                subtitle: "recipe.reduce.waste".localized,
                icon: "clock.arrow.circlepath",
                color: .red,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let expiringItems = foodGroups.flatMap { $0.items }
                        .filter { item in
                            if let days = item.daysUntilExpiration {
                                return days <= 3
                            }
                            return false
                        }
                    
                    let message: String
                    if !expiringItems.isEmpty {
                        // 创建详细的过期信息
                        let itemDescriptions = expiringItems.map { item in
                            let days = item.daysUntilExpiration ?? 0
                            if days <= 0 {
                                return viewModel.isEnglishMode
                                    ? "\(item.name) (already expired)"
                                    : "\(item.name)（已过期）"
                            } else {
                                return viewModel.isEnglishMode
                                    ? "\(item.name) (expires in \(days) day\(days == 1 ? "" : "s"))"
                                    : "\(item.name)（\(days)天后过期）"
                            }
                        }.joined(separator: viewModel.isEnglishMode ? ", " : "、")
                        
                        message = viewModel.isEnglishMode
                            ? "URGENT: Help me use these soon-to-expire ingredients before they go bad: \(itemDescriptions). Please prioritize these ingredients in your recipe suggestions and create something delicious that makes the most of their remaining freshness."
                            : "紧急任务：请帮我在这些食材变质前充分利用它们：\(itemDescriptions)。请在菜谱建议中优先使用这些食材，创作出美味的料理，充分利用它们剩余的新鲜度。"
                    } else {
                        message = viewModel.isEnglishMode
                            ? "Recommend recipes that are great for using up leftover vegetables and proteins to minimize food waste."
                            : "推荐一些适合清空冰箱、利用剩余蔬菜和肉类的食谱，减少食物浪费。"
                    }
                    checkAIUsageAndProceed(with: message, buttonId: "use_expiring")
                }
            }
            
            SmartRecipeButton(
                title: babyFoodTitle,
                subtitle: babyFoodSubtitle,
                icon: "figure.and.child.holdinghands",
                color: .pink,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let message = babyFoodMessage
                    checkAIUsageAndProceed(with: message, buttonId: "baby_food")
                }
            }
            
            SmartRecipeButton(
                title: "recipe.weight.loss".localized,
                subtitle: "recipe.low.calorie".localized,
                icon: "figure.run",
                color: .purple,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let variations = viewModel.isEnglishMode ? [
                        "Design a flavorful and satisfying meal under 400 calories that won't leave me hungry.",
                        "Create a high-protein, high-fiber dish specifically for weight management.",
                        "Suggest a light yet filling recipe that's packed with vegetables and a lean source of protein.",
                        "Recommend a low-calorie meal that still feels indulgent and delicious."
                    ] : [
                        "设计一道400卡路里以下，既美味又能提供强烈饱腹感的减脂餐。",
                        "创作一个专为体重管理设计的高蛋白、高纤维菜品。",
                        "推荐一个轻盈但管饱的食谱，要富含蔬菜和一种瘦肉蛋白。",
                        "推荐一道吃起来不像减脂餐的低卡美食，要美味、有满足感。"
                    ]
                    let message = variations[Int(Date().timeIntervalSince1970) % variations.count]
                    checkAIUsageAndProceed(with: message, buttonId: "weight_loss")
                }
            }
            
            SmartRecipeButton(
                title: "recipe.breakfast.energy".localized,
                subtitle: "recipe.start.day.right".localized,
                icon: "sunrise.fill",
                color: .cyan,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let variations = viewModel.isEnglishMode ? [
                        "Recommend a breakfast packed with complex carbs and protein for sustained energy all morning.",
                        "Suggest a quick and easy, yet highly energizing breakfast option for a busy start to the day.",
                        "Create a 'brain-food' breakfast with ingredients like berries and nuts to boost focus.",
                        "Design a balanced breakfast that's perfect for refueling after a morning workout."
                    ] : [
                        "推荐一份富含复合碳水和蛋白质的早餐，确保一上午都精力充沛。",
                        "为忙碌的早晨推荐一个快速、简单但能量十足的早餐选择。",
                        "创作一份'健脑'早餐，加入浆果、坚果等有助提高专注力的食材。",
                        "设计一款均衡的早餐，非常适合晨练后的能量补充。"
                    ]
                    let message = variations[Int(Date().timeIntervalSince1970) % variations.count]
                    checkAIUsageAndProceed(with: message, buttonId: "breakfast_energy")
                }
            }
            
            SmartRecipeButton(
                title: "recipe.elderly.care".localized,
                subtitle: "recipe.easy.digest".localized,
                icon: "figure.walk",
                color: .brown,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let variations = viewModel.isEnglishMode ? [
                        "Design a nutritious meal that is soft, flavorful, and easy to chew for seniors.",
                        "Suggest a dish that is easy to digest and gentle on the stomach, suitable for the elderly.",
                        "Create a recipe rich in calcium and lean protein, tailored for senior health.",
                        "Recommend a comforting, traditional-style dish with low sodium and controlled fats for older adults."
                    ] : [
                        "为老年人设计一款营养丰富、质地柔软、易于咀嚼的美味餐食。",
                        "推荐一道易于消化、对肠胃温和的菜品，特别适合老年人。",
                        "创作一个富含钙质和优质蛋白质的食谱，专为老年健康定制。",
                        "为老龄长者推荐一道低钠、控油的传统风味慰藉美食。"
                    ]
                    let message = variations[Int(Date().timeIntervalSince1970) % variations.count]
                    checkAIUsageAndProceed(with: message, buttonId: "elderly_care")
                }
            }
            
            SmartRecipeButton(
                title: seasonalTitle,
                subtitle: seasonalSubtitle,
                icon: seasonalIcon,
                color: seasonalColor,
                isDisabled: viewModel.isLoading,
                showAsGrayed: viewModel.isLoading || viewModel.familyMembers.isEmpty
            ) {
                if viewModel.familyMembers.isEmpty {
                    viewModel.showingFamilySetup = true
                } else if viewModel.hasNoIngredients {
                    viewModel.showingNoIngredientsAlert = true
                } else {
                    let message = seasonalMessage
                    checkAIUsageAndProceed(with: message, buttonId: "seasonal")
                }
            }
        }
        .id("recipe-buttons-\(viewModel.hasNoIngredients)-\(viewModel.familyMembers.count)-\(viewModel.isLoading)")
        .alert("ai.quota.exceeded.title".localized, isPresented: $showingQuotaExceededAlert) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text(quotaExceededMessage)
        }
    }
}