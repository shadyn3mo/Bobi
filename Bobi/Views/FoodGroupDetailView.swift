import SwiftUI
import SwiftData

struct FoodGroupDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    let group: FoodGroup
    @State private var showingAddItem = false
    @State private var showingDeleteAlert = false
    @State private var showingEditGroup = false
    
    private var sortedItems: [FoodItem] {
        group.items.sorted { item1, item2 in
            // 优先按过期时间排序
            guard let exp1 = item1.expirationDate, let exp2 = item2.expirationDate else {
                return item1.expirationDate != nil
            }
            return exp1 < exp2
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 组信息概览
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            // 组图标显示
                            VStack(spacing: 4) {
                                Text(group.displayIcon)
                                    .font(.largeTitle)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("food.group.total.items".localized(with: group.items.count))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("food.group.total.quantity.formatted".localized(with: group.formattedTotalQuantityWithUnit))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // 最早过期时间
                        if let expirationDate = group.earliestExpirationDate {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                Text("food.group.earliest.expiry".localized(with: DateFormatter.shortDate.string(from: expirationDate)))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 子项目列表
                Section("food.details.subitems".localized) {
                    ForEach(sortedItems, id: \.id) { item in
                        FoodSubItemRow(
                            item: item,
                            onUpdateUnit: updateItemUnit,
                            onUpdateQuantity: updateItemQuantity
                        )
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle(group.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("food.group.add.similar".localized, systemImage: "plus") {
                            showingAddItem = true
                        }
                        
                        Button("food.group.edit".localized, systemImage: "pencil") {
                            showingEditGroup = true
                        }
                        
                        Divider()
                        
                        Button("food.group.delete".localized, systemImage: "trash") {
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemToGroupView(group: group)
            }
            .sheet(isPresented: $showingEditGroup) {
                EditFoodGroupView(group: group)
                    
            }
            .alert("food.group.delete.alert.title".localized, isPresented: $showingDeleteAlert) {
                Button("food.group.delete.confirm".localized, role: .destructive) {
                    deleteGroup()
                }
                Button("food.group.cancel".localized, role: .cancel) { }
            } message: {
                Text("food.group.delete.alert.message".localized(with: group.displayName))
            }
        }
    }
    
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            let itemsToDelete = offsets.map { sortedItems[$0] }
            
            // 预先获取组的属性，避免删除后访问
            let groupDisplayName = group.displayName
            let _ = group.category
            
            // Store item details for history recording
            let itemsInfo = itemsToDelete.map { item in
                (name: item.name, quantity: Double(item.quantity), unit: item.unit, category: item.category, isExpired: item.isExpired)
            }
            
            for item in itemsToDelete {
                // 预先获取item的属性
                let _ = item.name
                let _ = item.category
                let _ = item.quantity
                let _ = item.unit
                
                // 先从组中移除
                group.removeItem(item)
                // 清理关系
                item.group = nil
                // 删除项目
                modelContext.delete(item)
            }
            
            // 检查组是否为空
            let shouldDeleteGroup = group.items.isEmpty
            
            if shouldDeleteGroup {
                modelContext.delete(group)
            }
            
            do {
                try modelContext.save()
                print("[FoodGroupDetailView] Successfully deleted \(itemsToDelete.count) items")
                
                // Record expiration in history for expired items
                Task {
                    for itemInfo in itemsInfo {
                        if itemInfo.isExpired {
                            await HistoryRecordService.shared.recordExpiration(
                                itemName: itemInfo.name,
                                quantity: itemInfo.quantity,
                                unit: itemInfo.unit,
                                category: itemInfo.category,
                                in: modelContext,
                                notes: "manually.deleted.expired.item".localized
                            )
                        }
                    }
                }
                
                // 如果删除了组，在保存成功后dismiss
                if shouldDeleteGroup {
                    print("[FoodGroupDetailView] Group \(groupDisplayName) became empty and was deleted")
                    dismiss()
                }
            } catch {
                print("[FoodGroupDetailView] Failed to delete items: \(error)")
                
                // 即使失败也要dismiss如果组被删除了
                if shouldDeleteGroup {
                    dismiss()
                }
            }
        }
    }
    
    private func deleteGroup() {
        withAnimation {
            // 在删除前先获取所有需要的数据，避免访问分离的属性
            let itemsToDelete = Array(group.items)
            let _ = group.category  // 预先获取category
            let groupDisplayName = group.displayName  // 预先获取displayName
            
            // Store item details for history recording
            let itemsInfo = itemsToDelete.map { item in
                (name: item.name, quantity: Double(item.quantity), unit: item.unit, category: item.category, isExpired: item.isExpired)
            }
            
            // 逐一删除项目并清理关系
            for item in itemsToDelete {
                // 预先获取item的所有需要属性
                let _ = item.name
                let _ = item.category
                let _ = item.quantity
                let _ = item.unit
                
                item.group = nil  // 先清理关系
                modelContext.delete(item)
            }
            
            // 删除组前确保不再访问其属性
            let groupToDelete = group
            modelContext.delete(groupToDelete)
            
            do {
                try modelContext.save()
                print("[FoodGroupDetailView] Successfully deleted group: \(groupDisplayName)")
                
                // Record expiration in history for expired items
                Task {
                    for itemInfo in itemsInfo {
                        if itemInfo.isExpired {
                            await HistoryRecordService.shared.recordExpiration(
                                itemName: itemInfo.name,
                                quantity: itemInfo.quantity,
                                unit: itemInfo.unit,
                                category: itemInfo.category,
                                in: modelContext,
                                notes: "manually.deleted.expired.item".localized
                            )
                        }
                    }
                }
                
                // 在保存成功后再dismiss
                dismiss()
            } catch {
                print("[FoodGroupDetailView] Failed to delete group: \(error)")
                // 如果保存失败，仍然尝试dismiss（但用户需要知道操作失败了）
                dismiss()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateItemUnit(_ item: FoodItem, newUnit: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            item.unit = newUnit
            
            // 尝试保存到数据库
            do {
                try modelContext.save()
                print("[FoodGroupDetailView] Updated unit for \(item.name) to \(newUnit)")
            } catch {
                print("[FoodGroupDetailView] Failed to save unit update: \(error)")
            }
        }
    }
    
    private func updateItemQuantity(_ item: FoodItem, newQuantity: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let oldQuantity = item.quantity
            item.quantity = newQuantity
            
            // 尝试保存到数据库
            do {
                try modelContext.save()
                print("[FoodGroupDetailView] Updated quantity for \(item.name) from \(oldQuantity) to \(newQuantity)")
                
                // 记录数量调整到历史记录
                Task {
                    await HistoryRecordService.shared.recordQuantityAdjustment(
                        itemName: item.name,
                        oldQuantity: Double(oldQuantity),
                        newQuantity: Double(newQuantity),
                        unit: item.unit,
                        category: item.category,
                        in: modelContext
                    )
                }
            } catch {
                print("[FoodGroupDetailView] Failed to save quantity update: \(error)")
            }
        }
    }
}

struct FoodSubItemRow: View {
    let item: FoodItem
    let onUpdateUnit: (FoodItem, String) -> Void
    let onUpdateQuantity: (FoodItem, Int) -> Void
    @State private var showingDetailSheet = false
    
    private var expirationStatus: (color: Color, text: String) {
        guard let daysUntil = item.daysUntilExpiration else {
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
        VStack(alignment: .leading, spacing: 4) {
            // 可点击的主要内容区域
            Button {
                showingDetailSheet = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let emoji = item.specificEmoji {
                                Text(emoji)
                                    .font(.title3)
                            }
                            Text(item.name)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text(item.formattedQuantityWithUnit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("food.group.purchase.date".localized(with: DateFormatter.shortDate.string(from: item.purchaseDate)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(expirationStatus.text)
                                .font(.caption)
                                .foregroundColor(expirationStatus.color)
                        }
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(expirationStatus.color)
                        .frame(width: 8, height: 8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 独立的单位引导区域（不在按钮内）
            if item.needsUnitGuidance {
                UnitGuidanceView(foodItem: item) { selectedUnit in
                    onUpdateUnit(item, selectedUnit)
                }
                .padding(.leading, 8) // 稍微缩进对齐
            }
        }
        .sheet(isPresented: $showingDetailSheet) {
            FoodDetailView(item: item)
        }
    }
}

struct AddItemToGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    let group: FoodGroup
    
    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var selectedUnit: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var expirationDate: Date = Date()
    @State private var hasExpirationDate: Bool = true
    
    init(group: FoodGroup) {
        self.group = group
        self._selectedUnit = State(initialValue: group.primaryUnit)
        self._name = State(initialValue: group.displayName)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("food.group.basic.info".localized) {
                    TextField("food.group.name.placeholder".localized, text: $name)
                    
                    HStack {
                        Text("food.details.quantity".localized)
                        Spacer()
                        HStack(spacing: 8) {
                            TextField("1", value: $quantity, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                            
                            Text(selectedUnit == FoodItem.defaultUnit ? "unit.item".localized : selectedUnit)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("food.group.dates".localized) {
                    DatePicker("food.group.purchase.date.label".localized, selection: $purchaseDate, displayedComponents: .date)
                    
                    Toggle("food.group.has.expiration".localized, isOn: $hasExpirationDate)
                    
                    if hasExpirationDate {
                        DatePicker("food.group.expiration.date.label".localized, selection: $expirationDate, in: purchaseDate..., displayedComponents: .date)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("food.group.add.to".localized(with: group.displayName))
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { saveItem() },
                saveEnabled: !name.isEmpty && quantity > 0,
                hasInput: !name.isEmpty
            )
        }
    }
    
    private func saveItem() {
        var finalQuantity = quantity
        var finalUnit = selectedUnit
        
        // Convert to standardized base units (g/mL/pcs) - same logic as other views
        if selectedUnit == "lbs" || selectedUnit == "磅" {
            finalQuantity = Int(Double(quantity) * 453.592)
            finalUnit = "g"
        } else if selectedUnit == "oz" || selectedUnit == "盎司" {
            finalQuantity = Int(Double(quantity) * 28.3495)
            finalUnit = "g"
        } else if selectedUnit == "kg" || selectedUnit == "公斤" {
            finalQuantity = Int(Double(quantity) * 1000)
            finalUnit = "g"
        } else if selectedUnit == "L" || selectedUnit == "升" {
            finalQuantity = Int(Double(quantity) * 1000)
            finalUnit = "mL"
        } else if selectedUnit == "gal" || selectedUnit == "加仑" {
            finalQuantity = Int(Double(quantity) * 3785)
            finalUnit = "mL"
        } else if selectedUnit == "cups" || selectedUnit == "杯" {
            finalQuantity = Int(Double(quantity) * 240)
            finalUnit = "mL"
        } else if selectedUnit == "tbsp" || selectedUnit == "大勺" {
            finalQuantity = Int(Double(quantity) * 15)
            finalUnit = "mL"
        } else if selectedUnit == "tsp" || selectedUnit == "小勺" {
            finalQuantity = Int(Double(quantity) * 5)
            finalUnit = "mL"
        } else if selectedUnit == "item" || selectedUnit == "个" || selectedUnit == "pcs" {
            finalUnit = FoodItem.defaultUnit
        }
        
        let newItem = FoodItem(
            name: name,
            purchaseDate: purchaseDate,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            category: group.category,
            quantity: finalQuantity,
            unit: finalUnit,
            specificEmoji: group.displayIcon
        )
        
        newItem.group = group
        group.addItem(newItem)
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            
            // 记录购买历史
            Task {
                await HistoryRecordService.shared.recordPurchase(
                    itemName: newItem.name,
                    quantity: Double(newItem.quantity),
                    unit: newItem.unit,
                    category: newItem.category,
                    in: modelContext
                )
            }
        } catch {
            print("Failed to save new item: \(error)")
        }
        
        dismiss()
    }
}

#Preview {
    let group = FoodGroup(baseName: "苹果", displayName: "苹果", category: .fruits)
    
    FoodGroupDetailView(group: group)
        .modelContainer(for: [FoodItem.self, FoodGroup.self], inMemory: true)
}