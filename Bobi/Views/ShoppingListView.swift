import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shoppingItems: [ShoppingListItem]
    @Query private var foodItems: [FoodItem]
    @State private var localizationManager = LocalizationManager.shared
    @State private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var showingHistory = false
    
    private var filteredShoppingItems: [ShoppingListItem] {
        let items = searchText.isEmpty ? shoppingItems : shoppingItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        
        // Sort by stock status: shortages first, then sufficient stock
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
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Premium Header Section
                            ShoppingHeaderSection(
                                geometry: geometry,
                                premiumBackgroundColors: premiumBackgroundColors,
                                premiumTitleGradient: premiumTitleGradient,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                                shortageCount: shortageItems.count,
                                totalItems: filteredShoppingItems.count
                            )
                            
                            // Content Section
                            ShoppingContentSection(
                                shortageItems: shortageItems,
                                sufficientItems: sufficientItems,
                                getCurrentStock: getCurrentStock,
                                formatCurrentStock: formatCurrentStock,
                                onDelete: deleteShoppingItem,
                                primaryTextColor: primaryTextColor,
                                searchText: $searchText,
                                showingAddItem: $showingAddItem,
                                showingHistory: $showingHistory
                            )
                        }
                    }
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .navigationBarHidden(true)
            // 注释：移除自动库存检查，改用精准的消耗后检查机制
            // 这避免了对未消耗食材的无关提醒
            .sheet(isPresented: $showingAddItem) {
                AddShoppingItemView()
            }
            .sheet(isPresented: $showingHistory) {
                HistoryOverviewView()
            }
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
    
    private func getCurrentStock(for item: ShoppingListItem) -> Int {
        let groupingService = FoodGroupingService.shared
        
        return foodItems
            .filter { foodItem in
                // 使用FoodGroupingService进行智能匹配
                return groupingService.shouldGroup(item.name, foodItem.name)
            }
            .reduce(0) { total, foodItem in
                // Both FoodItem and ShoppingListItem now use standardized units (g/mL)
                // so we can directly sum the quantities
                return total + foodItem.quantity
            }
    }
    
    private func formatCurrentStock(_ currentStock: Int, shoppingItem: ShoppingListItem) -> String {
        // Get matching food items to determine the actual unit type
        let groupingService = FoodGroupingService.shared
        let matchingFoodItems = foodItems.filter { foodItem in
            return groupingService.shouldGroup(shoppingItem.name, foodItem.name)
        }
        
        if let firstFood = matchingFoodItems.first {
            // Use the unit from the actual food item for proper formatting
            return UnitDisplayHelper.formatQuantityWithUnit(Double(currentStock), unit: firstFood.unit)
        } else {
            // Fallback: use shopping item's unit
            return UnitDisplayHelper.formatQuantityWithUnit(Double(currentStock), unit: shoppingItem.unit)
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
                Color.green.opacity(0.05),
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
                    Color.green.opacity(0.05),
                    Color(.secondarySystemBackground)
                ]
        }
    }
    
    var premiumTitleGradient: LinearGradient {
        LinearGradient(
            colors: [.green, .mint],
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
}

// MARK: - Shopping Header Section
struct ShoppingHeaderSection: View {
    let geometry: GeometryProxy
    let premiumBackgroundColors: [Color]
    let premiumTitleGradient: LinearGradient
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let shortageCount: Int
    let totalItems: Int
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image("shopping_view")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 95, height: 95)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("shopping.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(premiumTitleGradient)
                    
                    Text("shopping.subtitle".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
            }
            
            // Stats Cards
            HStack(spacing: 16) {
                StatsCard(
                    title: "shopping.stats.shortage".localized,
                    value: "\(shortageCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: shortageCount > 0 ? .red : .green
                )
                
                StatsCard(
                    title: "shopping.stats.total".localized,
                    value: "\(totalItems)",
                    icon: "list.clipboard.fill",
                    color: .green
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
                                colors: [.green.opacity(0.15), .clear],
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

// MARK: - Shopping Content Section
struct ShoppingContentSection: View {
    let shortageItems: [ShoppingListItem]
    let sufficientItems: [ShoppingListItem]
    let getCurrentStock: (ShoppingListItem) -> Int
    let formatCurrentStock: (Int, ShoppingListItem) -> String
    let onDelete: (ShoppingListItem) -> Void
    let primaryTextColor: Color
    @Binding var searchText: String
    @Binding var showingAddItem: Bool
    @Binding var showingHistory: Bool
    
    var body: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            // Search and Add Button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("shopping.search.placeholder".localized, text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(ResponsiveDesign.CornerRadius.medium)
                
                Button(action: { showingHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.purple)
                        .frame(width: 44, height: 44)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(ResponsiveDesign.CornerRadius.medium)
                }
                
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .cornerRadius(ResponsiveDesign.CornerRadius.medium)
                }
            }
            
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
                                currentStock: getCurrentStock(item),
                                formatCurrentStock: formatCurrentStock,
                                onDelete: { onDelete(item) }
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
                                currentStock: getCurrentStock(item),
                                formatCurrentStock: formatCurrentStock,
                                onDelete: { onDelete(item) }
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

// MARK: - Shopping Item Card
struct ShoppingItemCard: View {
    let item: ShoppingListItem
    let currentStock: Int
    let formatCurrentStock: (Int, ShoppingListItem) -> String
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    
    private var stockStatus: (color: Color, text: String, needsAttention: Bool) {
        if currentStock < item.minQuantity {
            return (.red, "shopping.status.low".localized, true)
        } else if currentStock < item.minQuantity + 2 {
            return (.orange, "shopping.status.medium".localized, false)
        } else {
            return (.green, "shopping.status.sufficient".localized, false)
        }
    }
    
    var body: some View {
        Button {
            showingEditSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.category.icon)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(item.category.localizedName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if stockStatus.needsAttention {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("shopping.current.stock".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrentStock(currentStock, item))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(stockStatus.color)
                    }
                    
                    HStack {
                        Text("shopping.threshold".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(item.formattedQuantityWithUnit)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    Circle()
                        .fill(stockStatus.color)
                        .frame(width: 8, height: 8)
                    
                    Text(stockStatus.text)
                        .font(.caption)
                        .foregroundColor(stockStatus.color)
                    
                    Spacer()
                    
                    if item.alertEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("shopping.edit".localized, systemImage: "pencil") {
                showingEditSheet = true
            }
            
            Button("shopping.delete".localized, systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditShoppingItemView(item: item)
        }
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: [ShoppingListItem.self, FoodItem.self], inMemory: true)
}