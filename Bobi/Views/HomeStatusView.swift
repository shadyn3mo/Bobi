import SwiftUI
import SwiftData

// MARK: - Modern Home Status View

struct HomeStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HomeStatusViewModel()
    @StateObject private var weatherThemeManager = WeatherThemeManager()
    @State private var localizationManager = LocalizationManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedMood: UserMood?
    @Binding var selectedTab: Int
    @State private var refreshTrigger = UUID() // 用于强制刷新本地化内容
    @State private var bobiAnimationOffset: CGFloat = 0
    @State private var showingAddItem = false
    @State private var showingSettings = false
    @State private var showingAddIngredientsConfirmation = false
    @State private var ingredientsToAdd: [String] = []
    @State private var ingredientsAddedToList = false
    @State private var recipeForDetail: MealSuggestion?
    
    // Bobi交互状态
    @State private var isAnimationPaused = false
    @State private var alternativeGreeting: String?
    @State private var greetingResetTimer: Timer?
    @State private var currentBobiImage = "cute1" // 当前显示的Bobi图片
    
    // 心情引导状态
    @State private var showingMoodPrompt = false
    @State private var promptAnimationScale: CGFloat = 1.0
    
    // Animation states
    @State private var cardAppearOffset: CGFloat = 30
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.9
    
    // Debug gesture states
    @State private var tapCount = 0
    @State private var tapTimer: Timer?
    
    var body: some View {
        mainNavigationView
    }
    
    // 将复杂的body拆分为更小的表达式
    private var mainNavigationView: some View {
        NavigationStack {
            addCompleteModifiers(baseContentView)
        }
        .id(refreshTrigger)
    }
    
    @ViewBuilder
    private func addCompleteModifiers<Content: View>(_ content: Content) -> some View {
        addStateChangeHandlers(
            addModalPresentations(
                addAlerts(
                    addNotificationHandlers(content)
                )
            )
        )
    }
    
    private var baseContentView: some View {
        ZStack {
            // Modern gradient background
            modernBackgroundView
            
            // 始终显示内容，不显示加载页面
            modernContentView
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setModelContext(modelContext)
            startAnimations()
            viewModel.loadInitialData() // 异步加载，不阻塞UI
            viewModel.checkMoodStatus() // 检查心情状态
            
            // 根据当前天气更新主题
            if let weather = viewModel.weatherInfo {
                weatherThemeManager.updateTheme(for: weather.condition)
            }
        }
        .onChange(of: viewModel.weatherInfo?.condition) { _, newCondition in
            // 当天气条件更新时，更新主题
            if let condition = newCondition {
                weatherThemeManager.updateTheme(for: condition)
            }
        }
        .onLongPressGesture(minimumDuration: 2.0) {
            // 调试功能：长按2秒切换到下一个天气主题进行测试
            cycleWeatherTheme()
        }
        .onTapGesture {
            // 调试功能：连点5下恢复到当前真实天气主题
            handleTapGesture()
        }
    }
    
    // MARK: - View Modifier Methods
    @ViewBuilder
    private func addStateChangeHandlers<Content: View>(_ content: Content) -> some View {
        content
            .onChange(of: selectedMood) { oldValue, newValue in
                if let mood = newValue {
                    viewModel.setUserMood(mood)
                    // 心情改变时重置按钮状态
                    ingredientsAddedToList = false
                    // 心情改变时也更新Bobi图片
                    updateBobiImage()
                }
            }
            .onChange(of: viewModel.mealSuggestion) { oldValue, newValue in
                // 当膳食建议改变时重置按钮状态
                ingredientsAddedToList = false
            }
    }
    
    @ViewBuilder
    private func addModalPresentations<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddItem) {
                AddFoodItemView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(item: $recipeForDetail) { recipe in
                NavigationStack {
                    RecipeDetailView(recipe: recipe)
                        .standardCancelToolbar {
                            recipeForDetail = nil
                        }
                }
            }
    }
    
    
    @ViewBuilder
    private func addAlerts<Content: View>(_ content: Content) -> some View {
        content
            .alert("recipe.ingredients.add_confirmation_title".localized, 
                   isPresented: $showingAddIngredientsConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("recipe.ingredients.add_all".localized) {
                    addIngredientsToShoppingList()
                    ingredientsAddedToList = true
                }
            } message: {
                Text("recipe.ingredients.add_confirmation_message".localized + 
                     "\n\n" + ingredientsToAdd.joined(separator: ", "))
            }
    }
    
    @ViewBuilder
    private func addNotificationHandlers<Content: View>(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
                // 语言变化时更新刷新触发器，强制重新渲染整个View
                refreshTrigger = UUID()
            }
            .onChange(of: viewModel.shouldPromptMoodSelection) { oldValue, newValue in
                if newValue && !oldValue {
                    // 当需要提醒时，启动动画
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        promptAnimationScale = 1.1
                    }
                } else if !newValue {
                    // 停止动画
                    withAnimation(.easeInOut(duration: 0.3)) {
                        promptAnimationScale = 1.0
                    }
                }
            }
    }
    
    // MARK: - Modern Background
    private var modernBackgroundView: some View {
        ZStack {
            // Base gradient with weather-adaptive colors
            weatherThemeManager.currentTheme.backgroundLinearGradient
                .ignoresSafeArea()
            
            // Weather-themed floating decoration circles
            Circle()
                .fill(weatherThemeManager.currentTheme.decorativeCircle1Gradient)
                .frame(width: 220, height: 220)
                .offset(x: -110, y: -220)
                .blur(radius: 25)
                .animation(.easeInOut(duration: 1.2), value: weatherThemeManager.currentWeather)
            
            Circle()
                .fill(weatherThemeManager.currentTheme.decorativeCircle2Gradient)
                .frame(width: 180, height: 180)
                .offset(x: 140, y: 320)
                .blur(radius: 20)
                .animation(.easeInOut(duration: 1.2).delay(0.3), value: weatherThemeManager.currentWeather)
            
            // Additional smaller accent circles for more atmosphere
            Circle()
                .fill(weatherThemeManager.currentTheme.primaryGradient.opacity(0.15))
                .frame(width: 100, height: 100)
                .offset(x: 80, y: -120)
                .blur(radius: 15)
                .animation(.easeInOut(duration: 1.0).delay(0.6), value: weatherThemeManager.currentWeather)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Modern Content Layout
    private var modernContentView: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 400
            
            ScrollView {
                VStack(spacing: 0) {
                    // 1. 温暖的欢迎区域
                    warmWelcomeSection
                        .padding(.horizontal, 20)
                    
                    // 主要内容区域间距
                    Spacer().frame(height: isSmallScreen ? 24 : 28)
                    
                    // 2. 心情选择区域
                    moodSelectionSection
                        .padding(.horizontal, 20)
                    
                    // 心情选择区域后的内容
                    if viewModel.shouldPromptMoodSelection {
                        // 心情选择到引导提示的间距
                        Spacer().frame(height: isSmallScreen ? 16 : 20)
                        
                        // 3. 心情引导提示
                        moodPromptSection
                            .padding(.horizontal, 20)
                    } else {
                        // 心情选择到餐品建议的间距
                        Spacer().frame(height: isSmallScreen ? 20 : 24)
                        
                        // 4. 餐品推荐卡片
                        recommendationCardsSection
                            .padding(.horizontal, 20)
                        
                        // 餐品推荐到食材添加的间距
                        Spacer().frame(height: isSmallScreen ? 24 : 28)
                        
                        // 5. 食材添加区域
                        addIngredientsSection
                            .padding(.horizontal, 20)
                    }
                    
                    // 底部安全间距
                    Spacer().frame(height: 30)
                }
                .padding(.top, 10)
            }
            .refreshable {
                await viewModel.refreshData()
            }
        }
    }
    
    // MARK: - 温暖的欢迎区域 (重构优化版)
    private var warmWelcomeSection: some View {
        VStack(spacing: 0) {
            // 上方：问候语区域
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(alternativeGreeting ?? viewModel.greeting)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(weatherThemeManager.currentTheme.primaryGradient)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.8), value: weatherThemeManager.currentWeather)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
            )
            
            // 下方：天气信息和Bobi头像
            HStack(spacing: 0) {
                // 左侧：天气信息
                if let weather = viewModel.weatherInfo {
                    HStack(spacing: 10) {
                        Image(systemName: weather.iconName)
                            .font(.system(size: 25, weight: .medium))
                            .foregroundColor(getWeatherColor(weather.condition))
                            .shadow(color: getWeatherColor(weather.condition).opacity(0.5), radius: 5)

                        Text("\(weather.description), \(String(format: "%.0f°C", weather.temperature))")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 24)
                } else {
                    // 没有天气信息时的占位
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 1, height: 1)
                        .padding(.leading, 24)
                }
                
                Spacer()
                
                // 右侧：Bobi头像
                Button(action: handleBobiTap) {
                    Image(getBobiImageName())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: weatherThemeManager.currentTheme.shadowColor, radius: 20, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.8), value: weatherThemeManager.currentWeather)
        // 优化的进入动画：从中心缩放+淡入+轻微下移
        .scaleEffect(cardScale)
        .offset(y: cardAppearOffset)
        .opacity(cardOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.1), value: cardAppearOffset)
        // 增加整体点击交互
        .onTapGesture {
            // 更新Bobi图片
            updateBobiImage()
            // 可以触发打开天气详情等操作
            print("Welcome card tapped! Updated Bobi image to: \(currentBobiImage)")
        }
    }
    
    // MARK: - 心情选择区域
    private var moodSelectionSection: some View {
        VStack(spacing: 24) { // 调整标题和选择器之间的间距
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                    .font(.title2)
                
                Text("mood.selection.title".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            modernMoodSelector
        }
        .padding(.top, 20) // 增加顶部内边距确保标题被完全覆盖
        .padding(.bottom, 20) // 增加底部内边距确保心情按钮被完全覆盖
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: weatherThemeManager.currentTheme.shadowColor, radius: 10, x: 0, y: 5)
        )
        .animation(.easeInOut(duration: 0.8), value: weatherThemeManager.currentWeather)
        .scaleEffect(cardScale)
        .offset(y: cardAppearOffset)
        .opacity(cardOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2), value: cardAppearOffset)
    }
    
    // MARK: - 心情引导提示区域
    private var moodPromptSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(.pink)
                    .font(.title2)
                    .scaleEffect(promptAnimationScale)
                
                Text("mood.prompt.title".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 显示心情有效期提醒
                if viewModel.lastMoodUpdateTime != nil {
                    let hoursRemaining = viewModel.getMoodRemainingHours()
                    if hoursRemaining > 0 {
                        Text(String(format: "mood.remaining.hours".localized, hoursRemaining))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.2))
                            )
                    }
                }
            }
            
            VStack(spacing: 12) {
                // 根据状态显示不同的提示信息
                if viewModel.currentMood == nil {
                    // 首次选择心情
                    VStack(spacing: 8) {
                        Text("mood.prompt.first_time".localized)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("mood.prompt.first_time_detail".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // 心情过期提醒
                    VStack(spacing: 8) {
                        Text("mood.prompt.refresh".localized)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("mood.prompt.refresh_detail".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // 指向心情选择区域的提示
                HStack {
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.pink)
                            .font(.title2)
                            .scaleEffect(promptAnimationScale)
                        
                        Text("mood.prompt.direction".localized)
                            .font(.caption)
                            .foregroundColor(.pink)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.pink.opacity(0.1),
                            Color.orange.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.pink.opacity(0.3), Color.orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .pink.opacity(colorScheme == .dark ? 0.2 : 0.3), radius: 15, x: 0, y: 8)
        )
        .scaleEffect(cardScale)
        .offset(y: cardAppearOffset)
        .opacity(cardOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.25), value: cardAppearOffset)
    }
    
    // MARK: - 推荐卡片区域
    private var recommendationCardsSection: some View {
        VStack(spacing: 16) {
            if viewModel.mealSuggestion != nil || viewModel.isMealSuggestionLoading {
                MealSuggestionCard(
                    suggestion: viewModel.mealSuggestion,
                    isLoading: viewModel.isMealSuggestionLoading
                ) {
                    // 点击餐品推荐卡片的操作
                    if let mealSuggestion = viewModel.mealSuggestion {
                        recipeForDetail = mealSuggestion
                    }
                }
                .scaleEffect(cardScale)
                .offset(y: cardAppearOffset)
                .opacity(cardOpacity)
                .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: cardAppearOffset)
            } else {
                // 根据心情状态显示不同的内容
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        Text("dish.recommendation.title".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        if viewModel.shouldPromptMoodSelection {
                            // 需要选择心情时的提示
                            VStack(spacing: 8) {
                                Image(systemName: "heart.circle")
                                    .foregroundColor(.pink)
                                    .font(.largeTitle)
                                
                                Text("meal.suggestion.mood_required".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("meal.suggestion.mood_required_detail".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // 指向心情选择区域的提示
                                HStack {
                                    Image(systemName: "arrow.up")
                                        .foregroundColor(.pink)
                                        .font(.caption)
                                    
                                    Text("mood.prompt.direction_up".localized)
                                        .font(.caption)
                                        .foregroundColor(.pink)
                                        .fontWeight(.medium)
                                }
                                .padding(.top, 8)
                            }
                        } else if viewModel.isDailyLimitReached {
                            // 达到每日AI限额时的提示
                            VStack(spacing: 16) {
                                Image(systemName: "hourglass.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                
                                Text("ai.daily.limit.exceeded".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("ai.daily.limit.exceeded.detail".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // 设置自定义API按钮
                                NavigationLink(destination: AIConnectionView()) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gear")
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        Text("ai.setup.custom.api".localized)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.blue)
                                    )
                                }
                            }
                        } else if viewModel.isAiGenerationFailed {
                            // AI生成失败时的提示
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                
                                Text("ai.service.unavailable".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("ai.service.unavailable.detail".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // 重试按钮
                                Button(action: {
                                    // 重新生成AI内容
                                    Task {
                                        await viewModel.manualRefresh()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        Text("ai.service.retry".localized)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.orange)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        } else if viewModel.hasWeatherInfo {
                            // 有天气信息但没有餐品建议，显示加载状态
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(.orange)
                                
                                Text("meal.suggestion.generating".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            // 没有天气信息，显示错误提示
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                                
                                Text("weather.fetch.failed".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("weather.fetch.failed_detail".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: weatherThemeManager.currentTheme.shadowColor, radius: 10, x: 0, y: 5)
                )
                .scaleEffect(cardScale)
                .offset(y: cardAppearOffset)
                .opacity(cardOpacity)
                .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: cardAppearOffset)
            }
        }
    }
    
    // MARK: - 食材添加到采购单区域
    private var addIngredientsSection: some View {
        VStack(spacing: 20) {
            // 现代化的标题区域
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: "cart.badge.plus")
                        .foregroundColor(.white)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("recipe.ingredients.add_to_cart".localized)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("recipe.ingredients.description".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            if let mealSuggestion = viewModel.mealSuggestion {
                VStack(spacing: 16) {
                    if !mealSuggestion.ingredients.isEmpty {
                        // 现代化的食材网格
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 12) {
                            ForEach(mealSuggestion.ingredients, id: \.self) { ingredient in
                                HStack(spacing: 8) {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(.green)
                                        .font(.subheadline)
                                        .frame(width: 18, height: 18)
                                    
                                    Text(ingredient)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        
                        // 现代化的按钮
                        Button(action: {
                            if !ingredientsAddedToList {
                                ingredientsToAdd = mealSuggestion.ingredients
                                showingAddIngredientsConfirmation = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: ingredientsAddedToList ? "checkmark.circle.fill" : "cart.fill.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(ingredientsAddedToList ? "recipe.ingredients.added".localized : "recipe.ingredients.add_all".localized)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: ingredientsAddedToList ? 
                                                [.green, .green.opacity(0.8)] : 
                                                [.blue, .blue.opacity(0.8)]
                                            ),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: (ingredientsAddedToList ? Color.green : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(ingredientsAddedToList)
                        .scaleEffect(ingredientsAddedToList ? 0.98 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: ingredientsAddedToList)
                    } else {
                        // AI推荐但没有具体食材列表的情况
                        VStack(spacing: 16) {
                            // 推荐菜品信息
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.orange)
                                        .font(.title3)
                                    
                                    Text("recipe.recommendation.prefix".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                
                                Text("\"\(mealSuggestion.dishName)\"")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Text("recipe.recommendation.description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                            
                            // 现代化的查看详细食谱按钮
                            Button(action: {
                                selectedTab = 2
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    
                                    Text("recipe.view.details".localized)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 16)
                    }
                }
            } else {
                // 等待推荐状态
                VStack(spacing: 16) {
                    // 动画图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue.opacity(0.2), .blue.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "cart.circle")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 8) {
                        Text("recipe.ingredients.waiting".localized)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("mood.selection.required".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: weatherThemeManager.currentTheme.shadowColor, radius: 10, x: 0, y: 5)
        )
        .scaleEffect(cardScale)
        .offset(y: cardAppearOffset)
        .opacity(cardOpacity)
        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.4), value: cardAppearOffset)
    }
    
    
    
    // MARK: - Modern Mood Selector
    private var modernMoodSelector: some View {
        GeometryReader { geometry in
            let isSmallScreen = geometry.size.width < 400 // iPhone SE, iPhone 12 mini等
            let spacing: CGFloat = isSmallScreen ? 8 : 16
            let horizontalPadding: CGFloat = isSmallScreen ? 4 : 8
            let frameHeight: CGFloat = isSmallScreen ? 130 : 140 // 增加高度以完全容纳按钮和内边距
            
            // 优雅的网格布局心情选择
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ], spacing: spacing) {
                ForEach(MoodType.allCases, id: \.self) { mood in
                    elegantMoodButton(for: mood, isSmallScreen: isSmallScreen)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, isSmallScreen ? 12 : 16) // 增加垂直内边距确保背景完全覆盖
            .frame(height: frameHeight)
        }
        .frame(height: 140) // 设置固定高度确保背景完全覆盖
    }
    
    private func elegantMoodButton(for mood: MoodType, isSmallScreen: Bool = false) -> some View {
        let isSelected = selectedMood?.mood == mood
        let buttonWidth: CGFloat = isSmallScreen ? 56 : 64
        let buttonHeight: CGFloat = isSmallScreen ? 72 : 80
        let emojiSize: CGFloat = isSmallScreen ? 28 : 32
        let fontSize: Font = isSmallScreen ? .caption2 : .caption
        let spacing: CGFloat = isSmallScreen ? 6 : 8
        
        return Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                selectedMood = UserMood(mood: mood)
            }
        }) {
            VStack(spacing: spacing) {
                Text(mood.emoji)
                    .font(.system(size: emojiSize))
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                
                Text(mood.localizedName)
                    .font(fontSize)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: buttonWidth, height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: isSmallScreen ? 12 : 16)
                    .fill(
                        isSelected ? 
                        weatherThemeManager.currentTheme.primaryGradient :
                        LinearGradient(
                            colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isSelected ? weatherThemeManager.currentTheme.shadowColor : weatherThemeManager.currentTheme.shadowColor.opacity(0.3),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
            .animation(.easeInOut(duration: 0.6), value: weatherThemeManager.currentWeather)
        }
        .buttonStyle(.plain)
    }
    
    private func moodButton(for mood: MoodType) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedMood = UserMood(mood: mood)
            }
        }) {
            VStack(spacing: 6) {
                Text(mood.emoji)
                    .font(.system(size: 28))
                
                Text(mood.localizedName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 60, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedMood?.mood == mood ? mood.color.opacity(0.2) : Color(.systemGray6))
            )
            .scaleEffect(selectedMood?.mood == mood ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMood?.mood)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Emotional Weather View
    private func emotionalWeatherView(weather: WeatherInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: weather.iconName)
                .foregroundColor(getWeatherColor(weather.condition))
                .font(.title3)
                .rotationEffect(.degrees(weather.condition == .sunny ? bobiAnimationOffset * 2 : 0))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(getEmotionalWeatherText(weather))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let location = weather.location {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    
    
    
    // MARK: - Helper Methods
    
    /// 添加食材到采购单
    private func addIngredientsToShoppingList() {
        let filteredIngredients = ingredientsToAdd.filter { ingredient in
            let (name, _, _) = IngredientParser.parseIngredientWithQuantity(ingredient)
            return !IngredientParser.isCondimentOrBasicSeasoning(name)
        }
        
        for ingredient in filteredIngredients {
            let (name, quantity, unit) = IngredientParser.parseIngredientWithQuantity(ingredient)
            let category = IngredientParser.guessIngredientCategory(name)
            let finalUnit = unit.isEmpty ? IngredientParser.getDefaultUnitForCategory(category) : unit
            let finalQuantity = quantity > 0 ? quantity : 1
            
            let shoppingItem = ShoppingListItem(
                name: name,
                category: category,
                unit: finalUnit,
                minQuantity: finalQuantity,
                alertEnabled: true
            )
            
            modelContext.insert(shoppingItem)
        }
        
        do {
            try modelContext.save()
            print("Successfully added \(filteredIngredients.count) ingredients to shopping list (filtered out \(ingredientsToAdd.count - filteredIngredients.count) condiments)")
        } catch {
            print("Failed to save ingredients to shopping list: \(error)")
        }
    }
    
    
    
    
    
    private func startAnimations() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.75, blendDuration: 0.3)) {
            cardAppearOffset = 0
            cardOpacity = 1
            cardScale = 1.0
        }
    }
    
    private func handleBobiTap() {
        // 暂停动画
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimationPaused = true
        }
        
        // 更新Bobi图片
        updateBobiImage()
        
        // 随机选择一个备选问候语
        let alternativeGreetings = [
            "bobi.random.greetings.1".localized,
            "bobi.random.greetings.2".localized,
            "bobi.random.greetings.3".localized,
            "bobi.random.greetings.4".localized,
            "bobi.random.greetings.5".localized,
            "bobi.random.greetings.6".localized,
            "bobi.random.greetings.7".localized,
            "bobi.random.greetings.8".localized,
            "bobi.random.greetings.9".localized,
            "bobi.random.greetings.10".localized,
            "bobi.random.greetings.11".localized,
            "bobi.random.greetings.12".localized
        ]
        
        alternativeGreeting = alternativeGreetings.randomElement()
        
        // 取消之前的定时器
        greetingResetTimer?.invalidate()
        
        // 5秒后恢复正常问候语和动画
        greetingResetTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                alternativeGreeting = nil
                isAnimationPaused = false
                
                // 重新启动动画
                withAnimation(.linear(duration: 0.1)) {
                    bobiAnimationOffset = 1
                }
            }
        }
        
        // 添加触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func getBobiImageName() -> String {
        return currentBobiImage
    }
    
    // 随机选择一个Bobi图片
    private func randomBobiImage() -> String {
        let bobiImages = ["cute1", "cute2", "cute3", "cute4"]
        // 确保不选择当前正在显示的图片
        let availableImages = bobiImages.filter { $0 != currentBobiImage }
        return availableImages.randomElement() ?? "cute1"
    }
    
    // 更新Bobi图片
    private func updateBobiImage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentBobiImage = randomBobiImage()
        }
    }
    
    private func getEmotionalWeatherText(_ weather: WeatherInfo) -> String {
        let temp = String(format: "%.0f°C", weather.temperature)
        
        switch weather.condition {
        case .sunny:
            return String(format: "weather.temp.sunny".localized, temp)
        case .rainy:
            return String(format: "weather.temp.rainy".localized, temp)
        case .cloudy:
            return String(format: "weather.temp.cloudy".localized, temp)
        case .cold:
            return String(format: "weather.temp.cold".localized, temp)
        case .hot:
            return String(format: "weather.temp.hot".localized, temp)
        case .windy:
            return String(format: "weather.temp.windy".localized, temp)
        case .snowy:
            return String(format: "weather.temp.snowy".localized, temp)
        }
    }
    
    private func getWeatherColor(_ condition: WeatherCondition) -> Color {
        switch condition {
        case .sunny: return .yellow
        case .cloudy: return .gray
        case .rainy: return .blue
        case .cold: return .cyan
        case .hot: return .red
        case .windy: return .mint
        case .snowy: return .white
        }
    }
    
    // MARK: - Debug Methods
    private func cycleWeatherTheme() {
        let allWeathers: [WeatherCondition] = [.sunny, .rainy, .cloudy, .cold, .hot, .windy, .snowy]
        
        if let currentIndex = allWeathers.firstIndex(of: weatherThemeManager.currentWeather) {
            let nextIndex = (currentIndex + 1) % allWeathers.count
            let nextWeather = allWeathers[nextIndex]
            
            // 提供触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // 更新主题
            weatherThemeManager.updateTheme(for: nextWeather)
            
            print("🌤️ Weather theme switched to: \(nextWeather)")
        }
    }
    
    private func handleTapGesture() {
        tapCount += 1
        
        // 取消之前的定时器
        tapTimer?.invalidate()
        
        // 设置新的定时器，1秒后重置计数
        tapTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            tapCount = 0
        }
        
        // 如果达到5次点击
        if tapCount >= 5 {
            restoreRealWeatherTheme()
            tapCount = 0
            tapTimer?.invalidate()
        }
    }
    
    private func restoreRealWeatherTheme() {
        // 恢复到真实天气主题
        if let realWeather = viewModel.weatherInfo?.condition {
            // 提供成功的触觉反馈
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            // 更新主题
            weatherThemeManager.updateTheme(for: realWeather)
            
            print("🔄 Weather theme restored to real weather: \(realWeather)")
        } else {
            // 如果没有真实天气数据，恢复到默认晴天主题
            let warningFeedback = UINotificationFeedbackGenerator()
            warningFeedback.notificationOccurred(.warning)
            
            weatherThemeManager.updateTheme(for: .sunny)
            
            print("⚠️ No real weather data, restored to default sunny theme")
        }
    }
}

