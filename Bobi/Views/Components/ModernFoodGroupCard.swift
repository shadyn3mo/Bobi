import SwiftUI
import SwiftData

struct ModernFoodGroupCard: View {
    let group: FoodGroup
    let onUpdateItemUnit: (FoodItem, String) -> Void
    @State private var showingGroupDetail = false
    @State private var showingEditGroup = false
    @State private var showingDeleteAlert = false
    @State private var groupName: String = ""
    @State private var groupID: UUID = UUID()
    @State private var isPressed = false
    @State private var visibleItemsCount = 3
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var localizationManager = LocalizationManager.shared
    @State private var themeManager = ThemeManager.shared
    @State private var handednessManager = HandednessManager.shared
    @Namespace private var glassNamespace
    
    private var statusColor: Color {
        guard let daysUntil = group.daysUntilExpiration else {
            return .green
        }
        
        if daysUntil < 0 {
            return .red
        } else if daysUntil <= 1 {
            return .orange
        } else if daysUntil <= 3 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        guard let daysUntil = group.daysUntilExpiration else {
            return "fridge.no.expiration".localized
        }
        
        if daysUntil < 0 {
            return "fridge.expired".localized
        } else if daysUntil == 0 {
            return "fridge.expires.today".localized
        } else if daysUntil == 1 {
            return "fridge.expires.tomorrow".localized
        } else {
            return "fridge.expires.in.days".localized(with: daysUntil)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showingGroupDetail = true
            }) {
            HStack(spacing: ResponsiveDesign.Spacing.medium) {
                // 食物图标 - 简化版
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: ResponsiveDesign.IconSize.large, height: ResponsiveDesign.IconSize.large)
                        .glassedEffect(in: Circle(), interactive: false)
                    
                    Text(group.displayIcon)
                        .font(.system(size: 28))
                }
                
                // 食物信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(group.displayName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                        
                        // 美化的数量标签
                        if group.items.count > 1 {
                            HStack(spacing: 4) {
                                Text("\(group.items.count)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(statusColor.opacity(0.8))
                                    )
                            }
                        }
                        
                        // 单位引导提示标识
                        if group.hasItemsNeedingUnitGuidance {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        if group.items.count == 1 {
                            // 单个物品显示数量+单位
                            Text(group.formattedTotalQuantityWithUnit)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        } else {
                            // 多个物品显示总数量
                            Text("\("fridge.total".localized): \(group.formattedTotalQuantityWithUnit)")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        // 状态指示器
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: ResponsiveDesign.IconSize.small * 0.5, height: ResponsiveDesign.IconSize.small * 0.5)
                            
                            Text(statusText)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(statusColor)
                        }
                    }
                    
                    // 子项目预览 - 使用ScrollView + LazyHStack进行横向优化
                    if group.items.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .center, spacing: 8) {
                                ForEach(Array(group.items.prefix(visibleItemsCount).enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 4) {
                                        Text("• \(item.name)")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(tertiaryTextColor)
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(statusColor.opacity(0.1))
                                            )
                                    }
                                    .onAppear {
                                        // 动态加载更多项目
                                        if index == visibleItemsCount - 1 && visibleItemsCount < min(group.items.count, 5) {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                visibleItemsCount = min(visibleItemsCount + 2, group.items.count)
                                            }
                                        }
                                    }
                                }
                                
                                if group.items.count > visibleItemsCount {
                                    Button(action: {
                                        showingGroupDetail = true
                                    }) {
                                        Text("+ \(group.items.count - visibleItemsCount)")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(statusColor)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(statusColor.opacity(0.15))
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(height: 28)
                    }
                    
                    // 单位引导提示移到了按钮外面
                }
                
                // 箭头指示器
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(tertiaryTextColor)
            }
            .padding(ResponsiveDesign.Spacing.medium)
            .background {
                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large))
            }
            .buttonStyle(PlainButtonStyle())
            
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                isPressed = pressing
            }
        }, perform: {})
        .contextMenu {
            contextMenuItems
        }
        .sheet(isPresented: $showingGroupDetail) {
            FoodGroupDetailView(group: group)
        }
        .sheet(isPresented: $showingEditGroup) {
            EditFoodGroupView(group: group)
        }
        .alert("fridge.delete.group.title".localized, isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.delete".localized, role: .destructive) {
                deleteGroup()
            }
        } message: {
            Text("fridge.delete.group.message".localized(with: groupName))
        }
        .onAppear {
            groupName = group.displayName
            groupID = group.id
        }
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color.secondary
    }
    
    private var tertiaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color(.tertiaryLabel)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color(.tertiarySystemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color(.separator).opacity(0.3)
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: {
            showingEditGroup = true
        }) {
            Label("common.edit".localized, systemImage: "pencil")
        }
        
        Button(action: {
            showingGroupDetail = true
        }) {
            Label("fridge.view.details".localized, systemImage: "info.circle")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            showingDeleteAlert = true
        }) {
            Label("common.delete".localized, systemImage: "trash")
        }
    }
    
    private func deleteGroup() {
        // 使用保存的 ID 来执行删除
        let idToDelete = groupID
        
        // 在主线程上执行删除操作
        Task { @MainActor in
            do {
                // 使用 FetchDescriptor 查找要删除的组
                let descriptor = FetchDescriptor<FoodGroup>(
                    predicate: #Predicate { foodGroup in
                        foodGroup.id == idToDelete
                    }
                )
                
                if let groupToDelete = try modelContext.fetch(descriptor).first {
                    // SwiftData 会通过级联删除规则自动删除相关的 items
                    modelContext.delete(groupToDelete)
                    
                    // 立即保存更改
                    try modelContext.save()
                }
            } catch {
                print("Failed to delete food group: \(error)")
            }
        }
    }
    
}

// 移除了老的按钮样式，使用更高级的 Liquid Glass 交互效果

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        let group = FoodGroup(baseName: "苹果", displayName: "苹果", category: .fruits)
        
        ModernFoodGroupCard(group: group) { item, unit in
            print("Updated \(item.name) to \(unit)")
        }
        .padding()
    }
}