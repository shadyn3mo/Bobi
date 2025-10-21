import SwiftUI

struct ContentView: View {
    @State private var localizationManager = LocalizationManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. 🌟 今日推荐 - 新增首页
            HomeStatusView(selectedTab: $selectedTab)
                .tabItem {
                    Label("tab.home".localized, systemImage: "star.fill")
                }
                .tag(0)
            
            // 2. 📦 我的冰箱 - 原库存页面
            MainInventoryView()
                .tabItem {
                    Label("tab.fridge".localized, systemImage: "refrigerator")
                }
                .tag(1)
            
            // 3. 👨‍🍳 Bobi厨房 - 原食谱页面
            RecipeView()
                .tabItem {
                    Label("tab.recipes".localized, systemImage: "flame")
                }
                .tag(2)
            
            // 4. ⚙️ 设置
            SettingsView()
                .tabItem {
                    Label("tab.settings".localized, systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            setupTabBarAppearance()
        }
        .onChange(of: colorScheme) { _, _ in
            setupTabBarAppearance()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // 每次应用变为活跃状态时清除角标
                NotificationManager.shared.clearBadgeNumber()
                
                // 只有当应用从后台恢复时才刷新通知，避免过度刷新
                if oldPhase == .background {
                    Task { @MainActor in
                        NotificationManager.shared.refreshNotifications()
                    }
                }
            }
        }
        .onAppear {
            // 清除应用启动时的角标
            NotificationManager.shared.clearBadgeNumber()
            
            // 设置定时器，每天检查一次通知
            setupDailyNotificationRefresh()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        // Configure tab bar background based on current color scheme
        if colorScheme == .dark {
            // Dark mode tab bar styling
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.shadowColor = UIColor.systemGray4
        } else {
            // Light mode tab bar styling  
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.shadowColor = UIColor.systemGray5
        }
        
        // Apply blur effect
        appearance.backgroundEffect = UIBlurEffect(style: colorScheme == .dark ? .systemMaterialDark : .systemMaterialLight)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func setupDailyNotificationRefresh() {
        // 创建一个每天凌晨2点检查通知的定时器
        let calendar = Calendar.current
        let now = Date()
        
        // 计算下一个凌晨2点的时间
        var nextRefresh = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: now) ?? now
        if nextRefresh <= now {
            nextRefresh = calendar.date(byAdding: .day, value: 1, to: nextRefresh) ?? now
        }
        
        let timer = Timer(fire: nextRefresh, interval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                NotificationManager.shared.refreshNotifications()
            }
        }
        
        RunLoop.main.add(timer, forMode: .common)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodItem.self, NutritionInfo.self, FamilyProfile.self, FamilyMember.self, ShoppingListItem.self], inMemory: true)
}
