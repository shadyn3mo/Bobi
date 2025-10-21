import SwiftUI
import SwiftData

struct RecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var foodGroups: [FoodGroup]
    @Query private var familyProfiles: [FamilyProfile]
    @StateObject private var viewModel = RecipeViewModel()
    @State private var localizationManager = LocalizationManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var currentLanguage: String = LocalizationManager.shared.selectedLanguage
    @State private var keyboardHeight: CGFloat = 0
    
    private var familyMembers: [FamilyMember] {
        if familyProfiles.count > 1 {
            print("⚠️ [RecipeView] Warning: Multiple family profiles detected (\(familyProfiles.count)). Using first one.")
            print("📋 [RecipeView] Family profiles: \(familyProfiles.map { "\($0.name) with \($0.members.count) members" })")
        }
        return familyProfiles.first?.members ?? []
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                GeometryReader { geometry in
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        
                        ScrollView {
                            VStack {
                                VStack(spacing: 0) {
                                    HeaderSection(
                                        viewModel: viewModel,
                                        geometry: geometry,
                                        premiumBackgroundColors: premiumBackgroundColors,
                                        premiumTitleGradient: premiumTitleGradient,
                                        primaryTextColor: primaryTextColor,
                                        secondaryTextColor: secondaryTextColor
                                    )
                                    
                                    MainContentSection(
                                        viewModel: viewModel,
                                        foodGroups: foodGroups,
                                        primaryTextColor: primaryTextColor,
                                        secondaryTextColor: secondaryTextColor,
                                        inputBackgroundColor: inputBackgroundColor,
                                        borderColor: borderColor
                                    )
                                }
                            }
                            .padding(.bottom, keyboardHeight > 0 ? max(keyboardHeight - 100, 0) : 0)
                        }
                    }
                }
                .navigationBarHidden(true)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            keyboardHeight = keyboardFrame.height
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        keyboardHeight = 0
                    }
                }
                .onChange(of: localizationManager.selectedLanguage) { oldLanguage, newLanguage in
                    if currentLanguage != newLanguage {
                        print("🌐 语言切换检测: \(currentLanguage) → \(newLanguage)")
                        print("🧹 清空聊天记录和推荐缓存")
                        
                        // 使用 DispatchQueue 来避免在视图更新期间直接修改状态
                        DispatchQueue.main.async {
                            viewModel.clearChatOnLanguageChange(newLanguage)
                            currentLanguage = newLanguage
                        }
                    }
                }
                .sheet(isPresented: $viewModel.showingFamilySetup) {
                    FamilySetupPromptView()
                }
                .alert("no.ingredients.alert.title".localized, isPresented: $viewModel.showingNoIngredientsAlert) {
                    Button("ok".localized, role: .cancel) { }
                } message: {
                    Text("no.ingredients.alert.message".localized)
                }
                .onAppear {
                    print("🔄 [RecipeView] onAppear - Updating data with \(foodGroups.count) food groups, \(familyMembers.count) family members")
                    viewModel.updateData(familyMembers: familyMembers, foodGroups: foodGroups)
                }
                .onChange(of: familyMembers) { _, _ in
                    viewModel.updateData(familyMembers: familyMembers, foodGroups: foodGroups)
                }
                .onChange(of: foodGroups) { _, _ in
                    viewModel.updateData(familyMembers: familyMembers, foodGroups: foodGroups)
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
            }
            
            if viewModel.isLoading {
                LoadingOverlayView(
                    stage: viewModel.currentLoadingStage,
                    onCancel: { viewModel.cancelCurrentRequest() }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
                .zIndex(999)
            }
        }
    }
    
    // MARK: - Theme Colors
    var premiumBackgroundColors: [Color] {
        switch themeManager.selectedTheme {
        case .dark:
            return [
                Color.black.opacity(0.98),
                Color(.systemGray5).opacity(0.8),
                Color.black.opacity(0.95)
            ]
        case .light:
            return [
                Color(.systemBackground),
                Color.yellow.opacity(0.05),
                Color(.secondarySystemBackground)
            ]
        case .auto:
            return colorScheme == .dark
                ? [
                    Color.black.opacity(0.98),
                    Color(.systemGray5).opacity(0.8),
                    Color.black.opacity(0.95)
                ]
                : [
                    Color(.systemBackground),
                    Color.yellow.opacity(0.05),
                    Color(.secondarySystemBackground)
                ]
        }
    }
    
    var premiumTitleGradient: LinearGradient {
        LinearGradient(
            colors: [.yellow, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color.secondary
    }
    
    var inputBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color(.systemGray6)
    }
    
    var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }
}

// MARK: - Header Section
struct HeaderSection: View {
    @ObservedObject var viewModel: RecipeViewModel
    let geometry: GeometryProxy
    let premiumBackgroundColors: [Color]
    let premiumTitleGradient: LinearGradient
    let primaryTextColor: Color
    let secondaryTextColor: Color
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image("cooking_view")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 95, height: 95)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("recipe.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(premiumTitleGradient)
                    
                    Text("recipe.subtitle".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
            }
            
            CompactNutritionInfo(
                calorieTarget: viewModel.cachedCalorieTarget,
                recommendedDishes: viewModel.recommendedDishCount
            )
            .id("nutrition-info-\(viewModel.familyMembers.count)")
            
            if viewModel.hasNoIngredients {
                NoIngredientsWarning()
            } else if viewModel.hasInsufficientIngredients {
                InsufficientIngredientsWarning(
                    availableCount: viewModel.availableIngredientsCount,
                    recommendedDishes: viewModel.recommendedDishCount
                )
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.bottom, ResponsiveDesign.Spacing.small)
        .padding(.top, 10)
        .background(
            GeometryReader { headerGeometry in
                LinearGradient(
                    colors: premiumBackgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.15), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: -100, y: -100)
                        .blur(radius: 20)
                )
                .frame(height: headerGeometry.size.height + geometry.safeAreaInsets.top)
                .offset(y: -geometry.safeAreaInsets.top)
            }
        )
    }
}

// MARK: - Main Content Section
struct MainContentSection: View {
    @ObservedObject var viewModel: RecipeViewModel
    let foodGroups: [FoodGroup]
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let inputBackgroundColor: Color
    let borderColor: Color
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.small) {
            SmartSuggestionsSection(viewModel: viewModel, foodGroups: foodGroups, primaryTextColor: primaryTextColor)
            
            if let recommendation = viewModel.lastRecommendation {
                LatestRecommendationSection(recommendation: recommendation, primaryTextColor: primaryTextColor)
            }
            
            CustomInputSection(
                viewModel: viewModel,
                secondaryTextColor: secondaryTextColor,
                inputBackgroundColor: inputBackgroundColor,
                borderColor: borderColor
            )
        }
        .padding(.top, ResponsiveDesign.Spacing.small)
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.bottom, ResponsiveDesign.Spacing.large)
    }
}

// MARK: - Smart Suggestions Section
struct SmartSuggestionsSection: View {
    @ObservedObject var viewModel: RecipeViewModel
    let foodGroups: [FoodGroup]
    let primaryTextColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
            Text("recipe.smart.suggestions".localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(primaryTextColor)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small),
                GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small),
                GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small)
            ], spacing: ResponsiveDesign.Spacing.small) {
                SmartRecipeButtonsGrid(viewModel: viewModel, foodGroups: foodGroups)
            }
        }
    }
}

// MARK: - Latest Recommendation Section
struct LatestRecommendationSection: View {
    let recommendation: ChatMessage
    let primaryTextColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.medium) {
            Text("recipe.latest.recommendation".localized)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(primaryTextColor)
                .padding(.top, ResponsiveDesign.Spacing.medium)
            
            RecommendationCard(message: recommendation)
        }
    }
}

// MARK: - Custom Input Section
struct CustomInputSection: View {
    @ObservedObject var viewModel: RecipeViewModel
    let secondaryTextColor: Color
    let inputBackgroundColor: Color
    let borderColor: Color
    @FocusState private var isTextFieldFocused: Bool
    
    var customInputTitle: String {
        if viewModel.lastRecommendation != nil {
            return "recipe.custom.request".localized
        } else {
            return "recipe.use.buttons.above".localized
        }
    }
    
    var customInputPlaceholder: String {
        if viewModel.lastRecommendation != nil {
            return "recipe.custom.placeholder".localized
        } else {
            return "recipe.buttons.recommendation".localized
        }
    }
    
    var shouldDisableInput: Bool {
        return viewModel.lastRecommendation == nil
    }
    
    var sendButtonColor: Color {
        if viewModel.userMessage.isEmpty || viewModel.isLoading {
            return Color.gray
        } else {
            return Color.blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
            Text(customInputTitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(secondaryTextColor)
            
            HStack {
                TextField(customInputPlaceholder, text: $viewModel.userMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                            .fill(shouldDisableInput ? inputBackgroundColor.opacity(0.3) : inputBackgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                            .stroke(shouldDisableInput ? borderColor.opacity(0.3) : borderColor, lineWidth: 1)
                    )
                    .lineLimit(1...3)
                    .disabled(viewModel.isLoading || shouldDisableInput)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !viewModel.userMessage.isEmpty && !shouldDisableInput {
                            viewModel.sendMessage()
                            isTextFieldFocused = false
                        }
                    }
                
                Button(action: { 
                    viewModel.sendMessage()
                    isTextFieldFocused = false
                }) {
                    ZStack {
                        Circle()
                            .fill(sendButtonColor)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(viewModel.userMessage.isEmpty || viewModel.isLoading || shouldDisableInput)
            }
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTextFieldFocused = false
                }
            }
        }
        .onChange(of: viewModel.lastRecommendation) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTextFieldFocused = false
            }
        }
    }
}