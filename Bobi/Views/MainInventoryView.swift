import SwiftUI
import SwiftData

struct MainInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(animation: .default) private var foodGroups: [FoodGroup]
    @Query private var shoppingItems: [ShoppingListItem]
    @Query private var foodItems: [FoodItem]
    @State private var localizationManager = LocalizationManager.shared
    @State private var handednessManager = HandednessManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    // View state
    @State private var selectedViewType: MainViewType = .inventory
    @State private var inventoryViewMode: InventoryViewMode = .byCategory
    @State private var showingAddItem = false
    @State private var showingVoiceInput = false
    @State private var showingReceiptScan = false
    @State private var showingAddShoppingItem = false
    @State private var showingHistory = false
    @State private var searchText = ""
    @State private var isSearchExpanded = false
    @State private var isShoppingSearchExpanded = false
    
    // Cache for performance
    @State private var cachedTotalItems: Int = 0
    @State private var cachedExpiringSoonCount: Int = 0
    @State private var lastFilterHash: Int = 0
    
    enum MainViewType: String, CaseIterable {
        case inventory = "inventory"
        case shopping = "shopping"
        
        var localizedName: String {
            switch self {
            case .inventory: return "tab.inventory".localized
            case .shopping: return "tab.shopping".localized
            }
        }
        
        var icon: String {
            switch self {
            case .inventory: return "refrigerator"
            case .shopping: return "list.clipboard"
            }
        }
    }
    
    enum InventoryViewMode: String, CaseIterable {
        case byCategory = "by_category"
        case byStorage = "by_storage"
        
        var localizedName: String {
            switch self {
            case .byCategory: return "view.by.category".localized
            case .byStorage: return "view.by.storage".localized
            }
        }
        
        var icon: String {
            switch self {
            case .byCategory: return "square.grid.2x2"
            case .byStorage: return "shippingbox"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Unified Header Section
                        headerSection(geometry: geometry)
                        
                        // Search and Toggle Controls
                        controlsSection
                        
                        // Content based on selected view type
                        contentSection
                    }
                }
                .coordinateSpace(name: "scroll")
                
                // Floating Action Button (only for inventory view)
                if selectedViewType == .inventory {
                    FloatingActionButton(
                        isRightHanded: handednessManager.isRightHanded,
                        onVoiceInput: { showingVoiceInput = true },
                        onManualAdd: { showingAddItem = true },
                        onReceiptScan: { showingReceiptScan = true }
                    )
                    .zIndex(999)
                }
            }
        }
        .onAppear {
            updateCacheIfNeeded()
        }
        .onChange(of: foodGroups.flatMap(\.items).map(\.quantity)) { oldQuantities, newQuantities in
            if oldQuantities != newQuantities {
                updateCacheIfNeeded()
            }
        }
        .onChange(of: searchText) { _, _ in
            updateCacheIfNeeded()
        }
        .onChange(of: inventoryViewMode) { _, _ in
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
        .sheet(isPresented: $showingAddShoppingItem) {
            AddShoppingItemView()
        }
        .sheet(isPresented: $showingHistory) {
            HistoryOverviewView()
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private func headerSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            // Icon and Title
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(headerGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: headerShadowColor, radius: 8, x: 0, y: 4)
                    
                    Image(headerImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: headerImageSize.width, height: headerImageSize.height)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedViewType == .inventory ? "fridge.title".localized : "shopping.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(headerGradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(selectedViewType == .inventory ? "fridge.subtitle".localized : "shopping.subtitle".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            
            // Stats Cards with integrated toggle
            VStack(spacing: 12) {
                // Integrated toggle as part of stats section
                MainViewTypeToggle(selectedViewType: $selectedViewType)
                
                HStack(spacing: ResponsiveDesign.Spacing.medium) {
                    if selectedViewType == .inventory {
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
                } else {
                    StatsCard(
                        title: "shopping.stats.shortage".localized,
                        value: "\(shortageItems.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: shortageItems.count > 0 ? .red : .green
                    )
                    
                    StatsCard(
                        title: "shopping.stats.total".localized,
                        value: "\(filteredShoppingItems.count)",
                        icon: "list.clipboard.fill",
                        color: .green
                    )
                }
            }
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
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [headerAccentColor.opacity(0.15), .clear],
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
    
    // MARK: - Controls Section
    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Search and secondary controls
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Search functionality
                if selectedViewType == .inventory {
                    DynamicSearchButton(searchText: $searchText, isExpanded: $isSearchExpanded)
                    
                    if !isSearchExpanded {
                        InventoryViewModeToggle(selectedMode: $inventoryViewMode)
                            .fixedSize(horizontal: true, vertical: false)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                } else {
                    // Shopping view search and controls
                    ShoppingSearchButton(searchText: $searchText, isExpanded: $isShoppingSearchExpanded)
                    
                    if !isShoppingSearchExpanded {
                        Button(action: { showingHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.purple)
                                .frame(width: 44, height: 44)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(ResponsiveDesign.CornerRadius.medium)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        
                        Button(action: { showingAddShoppingItem = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .cornerRadius(ResponsiveDesign.CornerRadius.medium)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            .animation(.smooth(duration: 0.4), value: isSearchExpanded)
            .animation(.smooth(duration: 0.4), value: isShoppingSearchExpanded)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Content Section
    @ViewBuilder
    private var contentSection: some View {
        if selectedViewType == .inventory {
            inventoryContent
        } else {
            shoppingContent
        }
    }
    
    // MARK: - Inventory Content
    @ViewBuilder
    private var inventoryContent: some View {
        LazyVStack(spacing: 12) {
            if inventoryViewMode == .byCategory {
                ForEach(filteredFoodGroups) { group in
                    ModernFoodGroupCard(group: group, onUpdateItemUnit: updateItemUnit)
                }
            } else {
                ForEach(groupedByStorage, id: \.0) { location, groups in
                    VStack(alignment: .leading, spacing: 12) {
                        // Storage location header
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
                        
                        // Food groups for this storage location
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
    
    // MARK: - Shopping Content
    @ViewBuilder
    private var shoppingContent: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Shortage Items Section
            if !shortageItems.isEmpty {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("shopping.section.shortage".localized)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small),
                        GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small)
                    ], spacing: ResponsiveDesign.Spacing.small) {
                        ForEach(shortageItems) { item in
                            ShoppingItemCard(
                                item: item,
                                currentStock: getCurrentStock(for: item),
                                formatCurrentStock: formatCurrentStock,
                                onDelete: { deleteShoppingItem(item) }
                            )
                        }
                    }
                }
            }
            
            // Sufficient Items Section
            if !sufficientItems.isEmpty {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.small) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("shopping.section.sufficient".localized)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small),
                        GridItem(.flexible(), spacing: ResponsiveDesign.Spacing.small)
                    ], spacing: ResponsiveDesign.Spacing.small) {
                        ForEach(sufficientItems) { item in
                            ShoppingItemCard(
                                item: item,
                                currentStock: getCurrentStock(for: item),
                                formatCurrentStock: formatCurrentStock,
                                onDelete: { deleteShoppingItem(item) }
                            )
                        }
                    }
                }
            }
            
            // Empty State
            if shortageItems.isEmpty && sufficientItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("shopping.empty.title".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryTextColor)
                    Text("shopping.empty.message".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.top, ResponsiveDesign.Spacing.small)
        .padding(.bottom, ResponsiveDesign.Spacing.large)
    }
}

// MARK: - Data Processing
extension MainInventoryView {
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
        let groups = inventoryViewMode == .byStorage ? filteredFoodGroups : []
        return StorageLocation.allCases.compactMap { location in
            let groupsForLocation = groups.filter { group in
                group.items.contains { $0.safeStorageLocation == location }
            }
            return groupsForLocation.isEmpty ? nil : (location, groupsForLocation)
        }
    }
    
    private var filteredShoppingItems: [ShoppingListItem] {
        let items = searchText.isEmpty ? shoppingItems : shoppingItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        return items.sorted { item1, item2 in
            let stock1 = getCurrentStock(for: item1)
            let stock2 = getCurrentStock(for: item2)
            let isShort1 = stock1 < item1.minQuantity
            let isShort2 = stock2 < item2.minQuantity
            
            if isShort1 && !isShort2 {
                return true
            } else if !isShort1 && isShort2 {
                return false
            } else {
                return item1.name < item2.name
            }
        }
    }
    
    private var shortageItems: [ShoppingListItem] {
        return filteredShoppingItems.filter { getCurrentStock(for: $0) < $0.minQuantity }
    }
    
    private var sufficientItems: [ShoppingListItem] {
        return filteredShoppingItems.filter { getCurrentStock(for: $0) >= $0.minQuantity }
    }
    
    private var totalItems: Int {
        return cachedTotalItems
    }
    
    private var expiringSoonCount: Int {
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
    
    private func getCurrentStock(for item: ShoppingListItem) -> Int {
        let groupingService = FoodGroupingService.shared
        
        return foodItems
            .filter { foodItem in
                return groupingService.shouldGroup(item.name, foodItem.name)
            }
            .reduce(0) { total, foodItem in
                return total + foodItem.quantity
            }
    }
    
    private func formatCurrentStock(_ currentStock: Int, shoppingItem: ShoppingListItem) -> String {
        let groupingService = FoodGroupingService.shared
        let matchingFoodItems = foodItems.filter { foodItem in
            return groupingService.shouldGroup(shoppingItem.name, foodItem.name)
        }
        
        if let firstFood = matchingFoodItems.first {
            return UnitDisplayHelper.formatQuantityWithUnit(Double(currentStock), unit: firstFood.unit)
        } else {
            return UnitDisplayHelper.formatQuantityWithUnit(Double(currentStock), unit: shoppingItem.unit)
        }
    }
    
    private func deleteShoppingItem(_ item: ShoppingListItem) {
        withAnimation {
            modelContext.delete(item)
            do {
                try modelContext.save()
            } catch {
                print("Failed to delete shopping item: \(error)")
            }
        }
    }
    
    private func updateItemUnit(_ item: FoodItem, newUnit: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            item.unit = newUnit
            
            do {
                try modelContext.save()
                print("[MainInventoryView] Updated unit for \(item.name) to \(newUnit)")
            } catch {
                print("[MainInventoryView] Failed to save unit update: \(error)")
            }
        }
    }
}

// MARK: - Theme and Styling
extension MainInventoryView {
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color.secondary
    }
    
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
                headerAccentColor.opacity(0.05),
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
                    headerAccentColor.opacity(0.05),
                    Color(.secondarySystemBackground)
                ]
        }
    }
    
    private var headerGradient: LinearGradient {
        selectedViewType == .inventory
            ? LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var headerShadowColor: Color {
        selectedViewType == .inventory ? .blue.opacity(0.3) : .green.opacity(0.3)
    }
    
    private var headerAccentColor: Color {
        selectedViewType == .inventory ? .cyan : .green
    }
    
    private var headerImageName: String {
        selectedViewType == .inventory ? "welcome_view" : "shopping_view"
    }
    
    private var headerImageSize: CGSize {
        selectedViewType == .inventory ? CGSize(width: 100, height: 100) : CGSize(width: 95, height: 95)
    }
}

// MARK: - Main View Type Toggle Component
struct MainViewTypeToggle: View {
    @Binding var selectedViewType: MainInventoryView.MainViewType
    @Environment(\.colorScheme) var colorScheme
    @State private var themeManager = ThemeManager.shared
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainInventoryView.MainViewType.allCases, id: \.self) { viewType in
                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedViewType = viewType
                    }
                }) {
                    HStack(spacing: ResponsiveDesign.Spacing.small * 0.75) {
                        Image(systemName: viewType.icon)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(viewType.localizedName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(selectedViewType == viewType ? .white : secondaryTextColor)
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.vertical, ResponsiveDesign.Spacing.small)
                    .frame(maxWidth: .infinity)
                    .background {
                        if selectedViewType == viewType {
                            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                                .fill(viewType == .inventory ? Color.blue : Color.green)
                                .matchedGeometryEffect(id: "mainToggle", in: animation)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium + 3)
                .fill(Color(.systemGray6).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium + 3)
                        .stroke(Color(.systemGray5).opacity(0.5), lineWidth: 0.5)
                )
        }
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .secondary
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }
    
    private var outerBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    private var capsuleBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5)
    }
}

// MARK: - Inventory View Mode Toggle Component
struct InventoryViewModeToggle: View {
    @Binding var selectedMode: MainInventoryView.InventoryViewMode
    @Environment(\.colorScheme) var colorScheme
    @State private var themeManager = ThemeManager.shared
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainInventoryView.InventoryViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedMode = mode
                    }
                }) {
                    HStack(spacing: ResponsiveDesign.Spacing.small * 0.67) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(mode.localizedName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(selectedMode == mode ? .primary : secondaryTextColor)
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.vertical, ResponsiveDesign.Spacing.small * 0.83)
                    .background {
                        if selectedMode == mode {
                            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                                .glassedEffect(in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium), interactive: true)
                                .matchedGeometryEffect(id: "inventoryToggle", in: animation)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(capsuleBackgroundColor)
                .overlay(
                    Capsule()
                        .stroke(outerBorderColor, lineWidth: 1)
                )
        }
        .glassedEffect(in: Capsule(), interactive: false)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .secondary
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }
    
    private var outerBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    private var capsuleBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5)
    }
}

#Preview {
    MainInventoryView()
        .modelContainer(for: [FoodItem.self, ShoppingListItem.self], inMemory: true)
}
//
