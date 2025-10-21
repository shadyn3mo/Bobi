import SwiftUI
import SwiftData

struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(animation: .default) private var foodGroups: [FoodGroup]
    @State private var localizationManager = LocalizationManager.shared
    @State private var handednessManager = HandednessManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAddItem = false
    @State private var showingVoiceInput = false
    @State private var showingReceiptScan = false
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .byCategory
    @State private var isSearchExpanded = false
    @State private var cachedTotalItems: Int = 0
    @State private var cachedExpiringSoonCount: Int = 0
    @State private var lastFilterHash: Int = 0
    
    
    enum ViewMode: String, CaseIterable {
        case byCategory = "by_category"
        case byStorage = "by_storage"
        
        var localizedName: String {
            switch self {
            case .byCategory: return "view.by.category".localized
            case .byStorage: return "view.by.storage".localized
            }
        }
    }
    
    private var filteredFoodGroups: [FoodGroup] {
        if searchText.isEmpty {
            return foodGroups.sorted { group1, group2 in
                guard let exp1 = group1.earliestExpirationDate, let exp2 = group2.earliestExpirationDate else {
                    return group1.earliestExpirationDate != nil
                }
                return exp1 < exp2
            }
        } else {
            return foodGroups.filter { group in
                group.displayName.localizedCaseInsensitiveContains(searchText) ||
                group.items.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    private var groupedByStorage: [(StorageLocation, [FoodGroup])] {
        let groups = viewMode == .byStorage ? filteredFoodGroups : []
        return StorageLocation.allCases.compactMap { location in
            let groupsForLocation = groups.filter { group in
                group.items.contains { $0.safeStorageLocation == location }
            }
            return groupsForLocation.isEmpty ? nil : (location, groupsForLocation)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 设置整体背景色
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部标题区域 - 优雅设计
                        VStack(spacing: 20) {
                            // Premium header similar to Settings and Nutrition pages
                            HStack(spacing: 16) {
                                // Fridge icon area
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 80, height: 80)
                                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Image("welcome_view")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("fridge.title".localized)
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .cyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Text("fridge.subtitle".localized)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                            }
                            
                            // 高级统计卡片和历史记录
                            HStack(spacing: ResponsiveDesign.Spacing.medium) {
                                StatsCard(
                                    title: "fridge.stats.categories".localized,
                                    value: "\(totalItems)",
                                    icon: "archivebox.fill",
                                    color: .blue
                                )
                                
                                StatsCard(
                                    title: "fridge.stats.expiring".localized,
                                    value: "\(expiringSoonCount)",
                                    icon: "clock.fill",
                                    color: .orange
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .padding(.top, 10)
                        .background(
                            GeometryReader { headerGeometry in
                                LinearGradient(
                                    colors: premiumBackgroundColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .overlay(
                                    // 光晕效果
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [.cyan.opacity(0.15), .clear],
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
                        
                        // 搜索布局
                        HStack(spacing: ResponsiveDesign.Spacing.small) {
                            // 动态搜索按钮
                            DynamicSearchButton(searchText: $searchText, isExpanded: $isSearchExpanded)
                            
                            // 动态胶囊式视图模式选择器
                            if !isSearchExpanded {
                                CapsuleViewModeToggle(selectedMode: $viewMode)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .animation(.smooth(duration: 0.4), value: isSearchExpanded)
                        .padding(.horizontal, ResponsiveDesign.Spacing.large)
                        .padding(.top, 10)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: proxy.frame(in: .named("scroll")).minY
                                    )
                                }
                            )
                        
                        // 食物列表
                        LazyVStack(spacing: 12) {
                            if viewMode == .byCategory {
                                ForEach(filteredFoodGroups) { group in
                                    ModernFoodGroupCard(group: group, onUpdateItemUnit: updateItemUnit)
                                }
                            } else {
                                ForEach(groupedByStorage, id: \.0) { location, groups in
                                    VStack(alignment: .leading, spacing: 12) {
                                        // 存储位置标题
                                        HStack(spacing: ResponsiveDesign.Spacing.small) {
                                            Text(location.icon)
                                                .font(.title2)
                                            Text(location.localizedName)
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(primaryTextColor)
                                            Spacer()
                                            Text("\(groups.reduce(0) { $0 + $1.items.count })")
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(primaryTextColor.opacity(0.7))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.1))
                                                        .overlay(
                                                            Capsule()
                                                                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                                                        )
                                                )
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.top, 8)
                                        
                                        // 该存储位置的食物组
                                        ForEach(groups) { group in
                                            ModernFoodGroupCard(group: group, onUpdateItemUnit: updateItemUnit)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ResponsiveDesign.Spacing.large)
                        .padding(.top, 24)
                        .padding(.bottom, ResponsiveDesign.floatingButtonBottomPadding)
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    // 可以在这里处理滚动偏移值，用于其他需要的动画
                }
                
                // 浮动操作按钮
                FloatingActionButton(
                    isRightHanded: handednessManager.isRightHanded,
                    onVoiceInput: { showingVoiceInput = true },
                    onManualAdd: { showingAddItem = true },
                    onReceiptScan: { showingReceiptScan = true }
                )
                .zIndex(999)
            }
        }
        .onAppear {
            print("InventoryListView appeared. Food groups count: \(foodGroups.count)")
            for group in foodGroups {
                print("- \(group.displayName) (\(group.items.count) items)")
            }
            updateCacheIfNeeded()
        }
        .onChange(of: foodGroups.flatMap(\.items).map(\.quantity)) { oldQuantities, newQuantities in
            // 注释：移除自动库存检查，改用精准的消耗后检查机制
            // 这避免了对未消耗食材的无关提醒
            if oldQuantities != newQuantities {
                updateCacheIfNeeded()
            }
        }
        .onChange(of: searchText) { _, _ in
            updateCacheIfNeeded()
        }
        .onChange(of: viewMode) { _, _ in
            updateCacheIfNeeded()
        }
        .sheet(isPresented: $showingAddItem) {
            AddFoodItemView()
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView()
        }
        .sheet(isPresented: $showingReceiptScan) {
            ReceiptScanView()
        }
    }
    
    private var totalItems: Int {
        return cachedTotalItems
    }
    
    private var expiringSoonCount: Int {
        // This is now calculated together with totalItems for efficiency
        return cachedExpiringSoonCount
    }
    
    private func updateCacheIfNeeded() {
        let currentHash = filteredFoodGroups.map { $0.id.uuidString }.joined().hashValue
        if currentHash != lastFilterHash {
            lastFilterHash = currentHash
            cachedTotalItems = filteredFoodGroups.reduce(0) { $0 + $1.items.count }
            cachedExpiringSoonCount = filteredFoodGroups.filter { group in
                if let days = group.daysUntilExpiration {
                    return days <= 3
                }
                return false
            }.count
        }
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color.secondary
    }
    
    // 高级主题相关的计算属性
    private var premiumBackgroundColors: [Color] {
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
                Color.cyan.opacity(0.05),
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
                    Color.cyan.opacity(0.05),
                    Color(.secondarySystemBackground)
                ]
        }
    }
    
    private var premiumTitleGradient: LinearGradient {
        switch themeManager.selectedTheme {
        case .dark:
            return LinearGradient(
                colors: [.white, .white.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [Color.primary, Color.primary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .auto:
            return colorScheme == .dark 
                ? LinearGradient(
                    colors: [.white, .white.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                : LinearGradient(
                    colors: [Color.primary, Color.primary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        }
    }
    
    private var statusBackgroundColor: Color {
        switch themeManager.selectedTheme {
        case .dark:
            return Color.white.opacity(0.1)
        case .light:
            return Color.black.opacity(0.05)
        case .auto:
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        }
    }
    
    // MARK: - Helper Methods
    private func updateItemUnit(_ item: FoodItem, newUnit: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            item.unit = newUnit
            
            // 尝试保存到数据库
            do {
                try modelContext.save()
                print("[InventoryListView] Updated unit for \(item.name) to \(newUnit)")
            } catch {
                print("[InventoryListView] Failed to save unit update: \(error)")
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollFadeModifier: ViewModifier {
    @State private var scrollOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollFadePreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
            )
            .onPreferenceChange(ScrollFadePreferenceKey.self) { value in
                scrollOffset = value
            }
            .opacity(calculateOpacity(scrollOffset: scrollOffset))
            .offset(y: calculateOffset(scrollOffset: scrollOffset))
            .animation(.easeOut(duration: 0.2), value: scrollOffset)
    }
    
    private func calculateOpacity(scrollOffset: CGFloat) -> Double {
        let referencePoint: CGFloat = 200 // 分类速览组件的位置参考点
        let fadeStartOffset: CGFloat = referencePoint - 50  // 开始渐隐的位置
        let fadeEndOffset: CGFloat = referencePoint - 150   // 完全消失的位置
        
        if scrollOffset >= fadeStartOffset {
            return 1.0
        } else if scrollOffset <= fadeEndOffset {
            return 0.0
        } else {
            let fadeRange = fadeStartOffset - fadeEndOffset
            let currentOffset = scrollOffset - fadeEndOffset
            return Double(currentOffset / fadeRange)
        }
    }
    
    private func calculateOffset(scrollOffset: CGFloat) -> CGFloat {
        let referencePoint: CGFloat = 200
        let offsetStartPoint: CGFloat = referencePoint - 30
        
        if scrollOffset < offsetStartPoint {
            return (offsetStartPoint - scrollOffset) * 0.5
        }
        return 0
    }
}

struct ScrollFadePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FoodGroupRow: View {
    let group: FoodGroup
    @State private var showingGroupDetailSheet = false
    
    private var expirationStatus: (color: Color, text: String) {
        guard let daysUntil = group.daysUntilExpiration else {
            return (.secondary, "fridge.no.expiration".localized)
        }
        
        if daysUntil < 0 {
            return (.red, "fridge.expired".localized)
        } else if daysUntil == 0 {
            return (.orange, "fridge.expires.today".localized)
        } else if daysUntil <= 7 {
            return (.orange, "fridge.expires.in.days".localized(with: daysUntil))
        } else {
            return (.green, "fridge.fresh".localized)
        }
    }
    
    var body: some View {
        Button {
            showingGroupDetailSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.displayIcon)
                            .font(.title2)
                        Text(group.displayName)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        if group.items.count > 1 {
                            Text("(\(group.items.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack {
                        Text("\(group.totalQuantity) \(group.displayUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(expirationStatus.text)
                            .font(.caption)
                            .foregroundColor(expirationStatus.color)
                    }
                    
                    // 显示子项目预览（最多3个）
                    if group.items.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(Array(group.items.prefix(3)), id: \.id) { item in
                                Text("• \(item.name)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            if group.items.count > 3 {
                                Text("...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(expirationStatus.color)
                    .frame(width: 12, height: 12)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 2)
        .sheet(isPresented: $showingGroupDetailSheet) {
            FoodGroupDetailView(group: group)
        }
    }
}


#Preview {
    InventoryListView()
        .modelContainer(for: FoodItem.self, inMemory: true)
        
}