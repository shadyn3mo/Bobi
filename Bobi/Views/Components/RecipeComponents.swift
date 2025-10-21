import SwiftUI
import SwiftData

// MARK: - Loading Components

// 🌟 重新设计的覆盖层加载指示器
struct LoadingOverlayView: View {
    let stage: LoadingStage
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: Double = 1.0
    
    // 响应式设计参数
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    private var scaleFactor: CGFloat {
        switch screenWidth {
        case 0...375:     // iPhone SE, iPhone 12/13/14/15 mini
            return 1.1    // 稍微放大一点
        case 376...414:   // iPhone 12/13/14/15, iPhone 11 Pro
            return 1.2    // 中等放大
        case 415...480:   // iPhone 11/XR, iPhone 14/15 Plus
            return 1.3    // 更大放大
        default:          // iPad and larger
            return 1.5    // 最大放大
        }
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景不取消，防止误操作
                }
            
            // 主加载卡片
            VStack(spacing: 24 * scaleFactor) {
                // 🌟 光感进度圆环
                ZStack {
                    // 外层光晕效果
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(0.3),
                                    Color.orange.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40 * scaleFactor,
                                endRadius: 80 * scaleFactor
                            )
                        )
                        .frame(width: 160 * scaleFactor, height: 160 * scaleFactor)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    
                    // 背景圆环
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6 * scaleFactor)
                        .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                    
                    // 🌟 渐变进度圆环
                    Circle()
                        .trim(from: 0, to: stage.progress)
                        .stroke(
                            AngularGradient(
                                colors: [.orange, .red, .pink, .orange],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 6 * scaleFactor, lineCap: .round)
                        )
                        .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: stage.progress)
                    
                    // 🌟 旋转光点效果
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                        .offset(y: -50 * scaleFactor)
                        .rotationEffect(.degrees(rotationAngle))
                        .opacity(stage.progress > 0 ? 1 : 0)
                        .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: rotationAngle)
                    
                    // 中心图标区域
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)
                            .overlay(
                                Circle()
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1 * scaleFactor)
                            )
                        
                        Image(systemName: stageIcon)
                            .font(.system(size: 24 * scaleFactor, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.3), value: stage)
                    }
                }
                
                // 状态信息区域
                VStack(spacing: 12 * scaleFactor) {
                    Text(stage.message)
                        .font(.system(size: 18 * scaleFactor, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: stage.message)
                    
                    Group {
                        switch stage {
                        case .generatingProgress(let progress):
                            VStack(spacing: 4 * scaleFactor) {
                                Text("\(Int(stage.progress * 100))%")
                                    .font(.system(size: 20 * scaleFactor, weight: .bold, design: .rounded))
                                Text(getThinkingMessage(for: progress))
                                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                                    .opacity(0.8)
                                    .multilineTextAlignment(.center)
                            }
                        default:
                            Text("\(Int(stage.progress * 100))%")
                                .font(.system(size: 20 * scaleFactor, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 0.3), value: stage.progress)
                }
                
                // 🌟 玻璃质感取消按钮
                Button(action: onCancel) {
                    HStack(spacing: 8 * scaleFactor) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16 * scaleFactor, weight: .semibold))
                        Text("recipe.cancel.request".localized)
                            .font(.system(size: 16 * scaleFactor, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20 * scaleFactor)
                    .padding(.vertical, 12 * scaleFactor)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5 * scaleFactor)
                    )
                    .scaleEffect(0.95)
                    .animation(.spring(response: 0.3), value: stage)
                }
                .buttonStyle(.plain)
            }
            .padding(32 * scaleFactor)
            .background(
                RoundedRectangle(cornerRadius: 24 * scaleFactor)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20 * scaleFactor, x: 0, y: 10 * scaleFactor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24 * scaleFactor)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1 * scaleFactor
                    )
            )
            .scaleEffect(0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: stage)
        }
        .onAppear {
            // 启动动画效果
            rotationAngle = 360
            pulseScale = 1.1
        }
    }
    
    private var stageIcon: String {
        switch stage {
        case .preparing: return "gear"
        case .analyzing: return "magnifyingglass.circle"
        case .generating: return "wand.and.stars"
        case .generatingProgress(_): return "brain.head.profile"
        case .formatting: return "doc.text.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private func getThinkingMessage(for progress: Double) -> String {
        let isEnglish = LocalizationManager.shared.selectedLanguage == "en"
        
        switch progress {
        case 0.0...0.3:
            return isEnglish ? "Analyzing ingredients..." : "分析食材搭配..."
        case 0.3...0.6:
            return isEnglish ? "Creating recipes..." : "构思美味菜谱..."
        case 0.6...0.85:
            return isEnglish ? "Perfecting details..." : "完善制作细节..."
        default:
            return isEnglish ? "Almost ready..." : "即将完成..."
        }
    }
}

// MARK: - Warning Components

// 食材不足警告组件
struct NoIngredientsWarning: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "basket")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("no.ingredients.title".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                
                Text("no.ingredients.description".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                .fill(.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }
}

struct InsufficientIngredientsWarning: View {
    let availableCount: Int
    let recommendedDishes: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("recipe.insufficient.ingredients".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("recipe.insufficient.suggestion".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                .fill(.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }
}

// MARK: - Button Components

// 智能食谱按钮组件
struct SmartRecipeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let showAsGrayed: Bool
    let isLoading: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var rotationAngle: Double = 0
    
    init(title: String, subtitle: String, icon: String, color: Color, isDisabled: Bool, isLoading: Bool = false, showAsGrayed: Bool? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.showAsGrayed = showAsGrayed ?? isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Always allow clicks, but check state in the action
            action()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(showAsGrayed ? 0.1 : 0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(showAsGrayed ? 0.1 : 0.3), lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.2), value: showAsGrayed)
                    
                    if isLoading {
                        // 🌟 简化的加载动画，避免CircularProgressViewStyle
                        ZStack {
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            
                            Circle()
                                .trim(from: 0, to: 0.7)
                                .stroke(color, lineWidth: 2)
                                .frame(width: 20, height: 20)
                                .rotationEffect(.degrees(rotationAngle))
                                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
                        }
                        .onAppear {
                            rotationAngle = 360
                        }
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(showAsGrayed ? color.opacity(0.4) : color)
                            .animation(.easeInOut(duration: 0.2), value: showAsGrayed)
                    }
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(showAsGrayed ? primaryTextColor.opacity(0.3) : primaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .frame(height: 48)
                        .animation(.easeInOut(duration: 0.2), value: showAsGrayed)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(showAsGrayed ? secondaryTextColor.opacity(0.3) : secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(height: 28)
                        .animation(.easeInOut(duration: 0.2), value: showAsGrayed)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 125)
            .padding(.vertical, 8)
        }
        .buttonStyle(InteractiveCardStyle(color: color))
        .disabled(isLoading) // Only disable when loading, not when ingredients/family empty
        .opacity(showAsGrayed ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: showAsGrayed)
        .drawingGroup()
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }
}

// MARK: - Recipe Display Components

// 推荐卡片组件
struct RecommendationCard: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("recipe.fresh.recommendation".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Formatted Recipe Content
            FormattedRecipeView(content: message.content)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.orange.opacity(0.1) : Color.orange.opacity(0.05)
    }
}

// 格式化食谱视图
struct FormattedRecipeView: View {
    let content: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @State private var cachedRecipes: [Dish] = []
    @State private var errorInfo: (code: String, message: String)? = nil
    @State private var lastParsedContent: String = ""
    @State private var isParsingContent = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isParsingContent && cachedRecipes.isEmpty && errorInfo == nil {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("recipe.parsing".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = errorInfo {
                RecipeErrorView(errorCode: error.code, errorMessage: error.message)
            } else {
                ForEach(Array(cachedRecipes.enumerated()), id: \.offset) { index, recipe in
                    RecipeItemView(recipe: recipe)
                        .padding(.bottom, index == cachedRecipes.count - 1 ? 0 : 12)
                }
            }
        }
        .onAppear {
            updateCacheIfNeeded()
        }
        .onChange(of: content) { _, _ in
            updateCacheIfNeeded()
        }
    }
    
    private func updateCacheIfNeeded() {
        guard content != lastParsedContent else { return }
        
        isParsingContent = true
        lastParsedContent = content
        
        Task.detached(priority: .userInitiated) {
            let recipeResponse = RecipeParser.shared.parseRecipeResponse(content)
            
            await MainActor.run {
                guard self.lastParsedContent == content else { return }
                
                if recipeResponse.isError {
                    self.errorInfo = (code: recipeResponse.errorCode ?? "UNKNOWN", message: recipeResponse.errorMessage ?? "Unknown error occurred")
                    self.cachedRecipes = []
                } else {
                    self.errorInfo = nil
                    self.cachedRecipes = recipeResponse.dishes
                }
                
                self.isParsingContent = false
            }
        }
    }
}

// 错误显示组件
struct RecipeErrorView: View {
    let errorCode: String
    let errorMessage: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("recipe.error.title".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text(localizedErrorCode)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                        )
                }
                
                Spacer()
            }
            
            Text(errorMessage)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(primaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 4)
            
            if errorCode == "HEALTH_CONFLICT" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        
                        Text("recipe.error.suggestion".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    
                    Text("recipe.error.health.suggestion".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(errorBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var localizedErrorCode: String {
        let key = "recipe.error.\(errorCode)"
        let localized = key.localized
        // If localization key doesn't exist, fall back to the original error code
        return localized != key ? localized : "recipe.error.UNKNOWN".localized
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var errorBackgroundColor: Color {
        colorScheme == .dark ? Color.red.opacity(0.1) : Color.red.opacity(0.05)
    }
}

// 烹饪步骤弹窗视图
struct CookingStepsSheet: View {
    let recipe: Dish
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private var isChineseMode: Bool {
        LocalizationManager.shared.selectedLanguage == "zh-Hans"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 菜品名称和菜系
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        if !recipe.cuisine.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "globe.asia.australia.fill")
                                    .font(.system(size: 12))
                                Text(recipe.cuisine)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 烹饪步骤
                    if !recipe.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("cooking.steps.title".localized)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            ForEach(recipe.steps, id: \.index) { step in
                                HStack(alignment: .top, spacing: 12) {
                                    // 步骤编号
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        
                                        Text("\(step.index)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    // 步骤内容
                                    Text(step.description)
                                        .font(.system(size: 18, weight: .regular))
                                        .lineSpacing(6)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                        }
                        .padding(.bottom)
                    } else {
                        Text("cooking.steps.none".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("cooking.guide.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

// 单个食谱项目视图
struct RecipeItemView: View {
    let recipe: Dish
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var showingCookingSteps = false
    @State private var showingIngredientConsumptionAlert = false
    @State private var isRecipeSelected = false
    @State private var showingAlreadySelectedAlert = false
    
    private var isChineseMode: Bool {
        LocalizationManager.shared.selectedLanguage == "zh-Hans"
    }
    
    var body: some View {
        Button(action: {
            if !recipe.steps.isEmpty {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showingCookingSteps = true
            }
        }) {
            recipeContent
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCookingSteps) {
            CookingStepsSheet(recipe: recipe)
        }
        .overlay(cookingStepsIndicator)
    }
    
    private var recipeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            dishHeader
            nutritionSection
            ingredientsSection
            healthTipSection
            cookRecipeSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(itemBackgroundColor)
                .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var dishHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                dishIcon
                dishNameText
            }
            
            if !recipe.cuisine.isEmpty {
                cuisineLabel
            }
        }
    }
    
    private var dishIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Image(systemName: "fork.knife")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var dishNameText: some View {
        Text(recipe.name)
            .font(isChineseMode ? .system(size: 18, weight: .bold, design: .default) : .system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [primaryTextColor, primaryTextColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var cuisineLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
            Text(recipe.cuisine)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    private var nutritionSection: some View {
        Group {
            if !recipe.nutritionHighlight.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("recipe.nutrition.title".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                        
                        Text(recipe.nutritionHighlight)
                            .font(isChineseMode ? .system(size: 14, weight: .medium) : .system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var ingredientsSection: some View {
        Group {
            if !recipe.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        Text("recipe.ingredients.title".localized)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                    
                    // 按分组显示食材
                    ForEach(recipe.ingredients, id: \.type.rawValue) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // 分组标题
                            HStack(spacing: 6) {
                                Image(systemName: iconForIngredientGroup(group.type))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(colorForIngredientGroup(group.type))
                                
                                Text(group.type.localizedName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(colorForIngredientGroup(group.type))
                            }
                            .padding(.horizontal, 4)
                            
                            // 该分组的食材列表
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 6) {
                                ForEach(Array(group.items.enumerated()), id: \.offset) { index, ingredient in
                                    HStack(alignment: .center, spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(colorForIngredientGroup(group.type).opacity(0.15))
                                                .frame(width: 18, height: 18)
                                            
                                            Text("\(index + 1)")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(colorForIngredientGroup(group.type))
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Text(ingredient.name)
                                                .font(isChineseMode ? .system(size: 13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(primaryTextColor)
                                            
                                            Text("\(ingredient.quantity)\(ingredient.unit)")
                                                .font(isChineseMode ? .system(size: 12, weight: .medium) : .system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                            
                                            // 状态标识
                                            if ingredient.status == .new {
                                                Text(ingredient.status.localizedName)
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.blue)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(ingredientItemBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(colorForIngredientGroup(group.type).opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
    }
    
    private var healthTipSection: some View {
        Group {
            if !recipe.healthyTip.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.15))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("recipe.tips.title".localized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                        
                        Text(recipe.healthyTip)
                            .font(isChineseMode ? .system(size: 14, weight: .medium) : .system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    @ViewBuilder
    private var cookingStepsIndicator: some View {
        if !recipe.steps.isEmpty {
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.orange))
                        .shadow(radius: 2)
                        .padding(8)
                }
                Spacer()
            }
        }
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color.secondary
    }
    
    private var itemBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.9)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    private var ingredientItemBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.green.opacity(0.05)
    }
    
    // MARK: - Ingredient Group Helpers
    private func iconForIngredientGroup(_ type: IngredientGroupType) -> String {
        switch type {
        case .main:
            return "fork.knife"
        case .side:
            return "carrot"
        case .seasoning:
            return "drop.fill"
        }
    }
    
    private func colorForIngredientGroup(_ type: IngredientGroupType) -> Color {
        switch type {
        case .main:
            return .orange
        case .side:
            return .green
        case .seasoning:
            return .blue
        }
    }
    
    private var cookRecipeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("recipe.cook.title".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            Button(action: {
                if isRecipeSelected {
                    showingAlreadySelectedAlert = true
                } else {
                    showingIngredientConsumptionAlert = true
                }
            }) {
                HStack {
                    Image(systemName: isRecipeSelected ? "checkmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isRecipeSelected ? .gray : .white)
                    
                    Text(isRecipeSelected ? "recipe.cook.selected".localized : "recipe.cook.button".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isRecipeSelected ? .gray : .white)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(isRecipeSelected ? .gray : .white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isRecipeSelected ? 
                            LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: isRecipeSelected ? .clear : .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .animation(.easeInOut(duration: 0.2), value: isRecipeSelected)
        }
        .alert("recipe.cook.confirm.title".localized, isPresented: $showingIngredientConsumptionAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("recipe.cook.confirm.button".localized, role: .destructive) {
                consumeIngredients()
                withAnimation(.easeInOut(duration: 0.3)) {
                    isRecipeSelected = true
                }
            }
        } message: {
            Text("recipe.cook.confirm.message".localized)
        }
        .alert("recipe.cook.already.selected.title".localized, isPresented: $showingAlreadySelectedAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("recipe.cook.again.button".localized, role: .destructive) {
                consumeIngredients()
            }
        } message: {
            Text("recipe.cook.already.selected.message".localized)
        }
    }
    
    private func consumeIngredients() {
        Task {
            do {
                print("🔍 开始消耗食材 for \(recipe.name)")
                print("🔍 食材列表: \(recipe.ingredients)")
                
                // Convert Dish to RecipeResponse for the consumption service
                let recipeResponse = RecipeResponse.success(dishes: [recipe])
                let result = try await IngredientConsumptionService.shared.consumeIngredientsForRecipe(recipeResponse, in: modelContext)
                
                await MainActor.run {
                    // 显示消耗结果
                    if !result.consumedIngredients.isEmpty {
                        print("✅ 成功消耗食材 for \(recipe.name):")
                        for consumed in result.consumedIngredients {
                            print("  - \(consumed.name): \(consumed.consumedAmount) \(consumed.unit)")
                        }
                    } else {
                        print("ℹ️ 没有消耗任何食材")
                    }
                    
                    if !result.warnings.isEmpty {
                        print("⚠️ 警告:")
                        for warning in result.warnings {
                            print("  - \(warning)")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ 消耗食材失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Nutrition Components

// 营养卡片组件
struct NutritionCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // 数值和标题
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                    
                    Text(unit.localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color(.tertiarySystemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }
    
}
