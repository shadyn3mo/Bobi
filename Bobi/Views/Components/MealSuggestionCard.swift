import SwiftUI

// MARK: - Meal Suggestion Card

struct MealSuggestionCard: View {
    let suggestion: MealSuggestion?
    let isLoading: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var themeManager = ThemeManager.shared
    
    // 加载动画状态
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            if isLoading {
                loadingStateView
            } else if let suggestion = suggestion {
                cardContent(suggestion)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
        )
        .onAppear {
            startLoadingAnimation()
        }
        .onChange(of: isLoading) { _, newValue in
            if newValue {
                startLoadingAnimation()
            } else {
                stopLoadingAnimation()
            }
        }
    }
    
    // MARK: - 加载状态视图
    private var loadingStateView: some View {
        VStack(spacing: 20) {
            // 加载动画
            ZStack {
                // 外层脉动光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.3),
                                Color.orange.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseScale)
                
                // 进度圆环
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [.orange, .red],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: rotationAngle)
                
                // 中心图标
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            
            // 加载文本
            VStack(spacing: 8) {
                Text("meal.suggestion.generating".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryTextColor)
                
                Text("meal.suggestion.generating.detail".localized)
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 卡片内容
    private func cardContent(_ suggestion: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.meal.suggestion.title".localized)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(primaryTextColor)
                    
                    HStack(spacing: 4) {
                        Image(systemName: suggestion.mealType.iconName)
                            .foregroundColor(suggestion.mealType.color)
                            .font(.subheadline)
                        
                        Text(suggestion.mealType.localizedName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Spacer()
                
                // Urgency indicator
                if suggestion.urgency == .high {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                
                Image(systemName: "hand.tap")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.orange)
                    )
            }
            
            // Dish name
            Text(suggestion.dishName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryTextColor)
                .lineLimit(2)
            
            // Reason
            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
                .lineLimit(3)
            
            // Quick stats
            HStack(alignment: .center, spacing: 0) {
                // Cooking time
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    
                    Text(suggestion.cookingTimeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
                
                // Difficulty - 居中显示
                HStack(spacing: 6) {
                    Image(systemName: suggestion.difficulty.iconName)
                        .foregroundColor(suggestion.difficulty.color)
                        .font(.subheadline)
                    
                    Text(suggestion.difficulty.localizedName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(primaryTextColor)
                }
                
                Spacer()
                
                // Suitability - 右对齐
                Text(suggestion.suitability)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
            }
            
            // Ingredients preview
            if !suggestion.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("home.meal.ingredients.preview".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(suggestion.ingredients.prefix(4)), id: \.self) { ingredient in
                                IngredientChip(name: ingredient)
                            }
                            
                            if suggestion.ingredients.count > 4 {
                                Text("+\(suggestion.ingredients.count - 4)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.2))
                                    )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            
            // Nutrition highlights
            if !suggestion.nutritionHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("home.meal.nutrition.highlights".localized)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)
                    
                    HStack(spacing: 8) {
                        ForEach(Array(suggestion.nutritionHighlights.prefix(3)), id: \.self) { highlight in
                            NutritionHighlightChip(text: highlight)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Recipe preview
            if !suggestion.recipePreview.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "text.quote")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    Text(suggestion.recipePreview)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(primaryTextColor)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding(20)
    }
    
    // MARK: - 动画控制
    private func startLoadingAnimation() {
        guard isLoading else { return }
        
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
    
    private func stopLoadingAnimation() {
        // 重置动画状态
        withAnimation(.none) {
            rotationAngle = 0
            pulseScale = 1.0
        }
    }
    
    // MARK: - 主题色彩
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color.secondary
    }
    
    private var cardBackgroundColor: Color {
        switch themeManager.selectedTheme {
        case .dark:
            return Color(.systemGray6).opacity(0.3)
        case .light:
            return Color(.systemBackground)
        case .auto:
            return colorScheme == .dark 
                ? Color(.systemGray6).opacity(0.3)
                : Color(.systemBackground)
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark 
            ? Color.black.opacity(0.3)
            : Color.black.opacity(0.1)
    }
}

// MARK: - 食材芯片组件
struct IngredientChip: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.15))
            )
    }
}

// MARK: - 营养高亮芯片组件
struct NutritionHighlightChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // 加载状态
        MealSuggestionCard(
            suggestion: nil,
            isLoading: true,
            onTap: {}
        )
        
        // 正常状态
        MealSuggestionCard(
            suggestion: MealSuggestion(
                dishName: "番茄鸡蛋面",
                reason: "温暖的午后，来一碗简单美味的番茄鸡蛋面",
                cookingTime: 15,
                difficulty: .easy,
                ingredients: ["鸡蛋", "番茄", "面条"],
                nutritionHighlights: ["蛋白质", "维生素C"],
                recipePreview: "简单快手的家常面条"
            ),
            isLoading: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGray6))
}