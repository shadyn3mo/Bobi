//
//  RecipeDetailView.swift
//  Bobi
//
//  详细食谱弹窗视图
//

import SwiftUI
import Charts

struct RecipeDetailView: View {
    let recipe: MealSuggestion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // 缓存的营养成分数据，避免重复计算
    private var nutritionComponents: [NutritionComponent] {
        generateNutritionComponents()
    }
    
    init(recipe: MealSuggestion) {
        self.recipe = recipe
    }
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    // 头部信息
                    headerSection
                    
                    // 食材列表
                    if !recipe.ingredients.isEmpty {
                        ingredientsSection
                    }
                    
                    // 营养成分（模拟数据）
                    nutritionSection
                    
                    // 制作步骤（基于reason解析）
                    cookingStepsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
        .navigationTitle(recipe.dishName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 菜品类型和信息
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Label(recipe.mealType.localizedName, systemImage: recipe.mealType.iconName)
                        .font(.subheadline)
                        .foregroundColor(recipe.mealType.color)
                    
                    Label(recipe.difficulty.localizedName, systemImage: recipe.difficulty.iconName)
                        .font(.subheadline)
                        .foregroundColor(recipe.difficulty.color)
                    
                    Label(recipe.cookingTimeText, systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // 推荐理由
            if !recipe.reason.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("recipe.detail.reason.title".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(recipe.reason)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recipe.detail.ingredients.title".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption2)
                        
                        Text(ingredient)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Nutrition Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("recipe.detail.nutrition.title".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 营养成分饼状图（模拟数据）
            nutritionChart
            
            // 详细营养数值
            if let nutritionData = recipe.nutritionData {
                nutritionDetailsView(nutritionData)
            }
            
            // 营养亮点
            if !recipe.nutritionHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("recipe.detail.nutrition.highlights".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        ForEach(recipe.nutritionHighlights, id: \.self) { highlight in
                            Text(highlight)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.2))
                                )
                                .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // 营养成分饼状图
    private var nutritionChart: some View {
        let nutritionData = nutritionComponents
        
        return VStack(spacing: 12) {
            // 饼状图
            if #available(iOS 17.0, *) {
                Chart(nutritionData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Value", item.value)
                    )
                    .foregroundStyle(item.color)
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, alignment: .center)
            } else {
                // iOS 16 fallback - 简化版本以提高性能
                VStack(spacing: 12) {
                    // 简化的圆形图表
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Text("nutrition".localized)
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    
                    // 营养成分列表
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(nutritionData, id: \.name) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(item.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(Int(item.value))%")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Cooking Steps Section
    private var cookingStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("recipe.detail.steps.title".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 16) {
                // 使用AI生成的制作步骤，如果没有则使用解析的步骤
                let steps = getCookingSteps()
                
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        // 步骤编号
                        Text("\(index + 1)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.blue)
                            )
                        
                        // 步骤内容
                        Text(step)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Methods
    
    /// 获取制作步骤
    private func getCookingSteps() -> [String] {
        // 优先使用AI生成的制作步骤
        if !recipe.cookingSteps.isEmpty {
            return recipe.cookingSteps
        }
        
        // 回退到从reason解析步骤
        return parseCookingSteps(from: recipe.reason)
    }
    
    /// 生成营养成分数据
    private func generateNutritionComponents() -> [NutritionComponent] {
        // 如果有AI生成的营养数据，使用真实数据
        if let nutritionData = recipe.nutritionData {
            let total = nutritionData.protein + nutritionData.carbs + nutritionData.fat + nutritionData.fiber
            
            if total > 0 {
                return [
                    NutritionComponent(name: "nutrition.carbs".localized, value: (nutritionData.carbs / total) * 100, color: .blue),
                    NutritionComponent(name: "nutrition.protein".localized, value: (nutritionData.protein / total) * 100, color: .green),
                    NutritionComponent(name: "nutrition.fat".localized, value: (nutritionData.fat / total) * 100, color: .orange),
                    NutritionComponent(name: "nutrition.fiber".localized, value: (nutritionData.fiber / total) * 100, color: .purple)
                ]
            }
        }
        
        // 回退到默认模拟数据
        return [
            NutritionComponent(name: "nutrition.carbs".localized, value: 45, color: .blue),
            NutritionComponent(name: "nutrition.protein".localized, value: 25, color: .green),
            NutritionComponent(name: "nutrition.fat".localized, value: 20, color: .orange),
            NutritionComponent(name: "nutrition.other".localized, value: 10, color: .gray)
        ]
    }
    
    /// 营养详细数值视图
    private func nutritionDetailsView(_ nutritionData: NutritionData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("recipe.detail.nutrition.details".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                nutritionDetailRow("nutrition.protein".localized, value: nutritionData.protein, unit: "g", color: .green)
                nutritionDetailRow("nutrition.carbs".localized, value: nutritionData.carbs, unit: "g", color: .blue)
                nutritionDetailRow("nutrition.fat".localized, value: nutritionData.fat, unit: "g", color: .orange)
                nutritionDetailRow("nutrition.fiber".localized, value: nutritionData.fiber, unit: "g", color: .purple)
            }
            
            // 热量单独显示
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                
                Text("nutrition.calories".localized)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(nutritionData.calories)) kcal")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
            )
        }
    }
    
    /// 营养详细行
    private func nutritionDetailRow(_ name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    /// 解析制作步骤（回退方法）
    private func parseCookingSteps(from reason: String) -> [String] {
        // 从reason中提取烹饪提示
        let lines = reason.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.contains("💡") }
        
        if !lines.isEmpty {
            // 如果有烹饪提示，提取并转换为步骤
            let tips = lines.compactMap { line in
                line.replacingOccurrences(of: "💡 ", with: "")
            }
            return tips
        }
        
        // 默认通用步骤
        return generateDefaultSteps(for: recipe.dishName)
    }
    
    /// 生成默认制作步骤
    private func generateDefaultSteps(for dishName: String) -> [String] {
        let lowercased = dishName.lowercased()
        
        if lowercased.contains("面") || lowercased.contains("noodle") {
            return [
                "准备所需食材，洗净切好",
                "烧开水，下面条煮制",
                "热锅下油，爆炒配菜",
                "加入调料调味",
                "将面条和配菜混合，装盘即可"
            ]
        } else if lowercased.contains("汤") || lowercased.contains("soup") {
            return [
                "准备所需食材，洗净处理",
                "热锅下油，爆炒香料",
                "加入主要食材翻炒",
                "倒入适量清水或高汤",
                "小火慢炖，调味即可"
            ]
        } else if lowercased.contains("炒") || lowercased.contains("stir") {
            return [
                "准备所需食材，洗净切块",
                "热锅下油，爆炒蒜蓉",
                "下主料大火翻炒",
                "加入调料炒匀",
                "起锅装盘，即可享用"
            ]
        } else {
            return [
                "准备并清洗所有食材",
                "按照食材特性进行预处理",
                "按顺序下锅烹制",
                "适时调味，确保口感",
                "装盘摆设，完成制作"
            ]
        }
    }
}

// MARK: - Nutrition Component Model
struct NutritionComponent {
    let name: String
    let value: Double
    let color: Color
}

// MARK: - Localization
extension String {
    static let recipeDetailReasonTitle = "recipe.detail.reason.title"
    static let recipeDetailIngredientsTitle = "recipe.detail.ingredients.title"
    static let recipeDetailNutritionTitle = "recipe.detail.nutrition.title"
    static let recipeDetailNutritionHighlights = "recipe.detail.nutrition.highlights"
    static let recipeDetailNutritionDetails = "recipe.detail.nutrition.details"
    static let recipeDetailStepsTitle = "recipe.detail.steps.title"
}

// MARK: - Preview
#Preview {
    RecipeDetailView(recipe: MealSuggestion.mockSuggestions.first!)
}