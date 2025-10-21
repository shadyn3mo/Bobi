import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    let item: FoodItem
    
    @State private var name: String
    @State private var selectedCategory: FoodCategory
    @State private var quantity: Int
    @State private var selectedUnit: String
    @State private var purchaseDate: Date
    @State private var expirationDate: Date?
    @State private var hasExpirationDate: Bool
    @State private var stockAlertEnabled: Bool
    @State private var showingDeleteAlert = false
    @State private var showingEmojiPicker = false
    @State private var selectedEmoji: String?
    @State private var storageLocation: StorageLocation
    @State private var recommendedStorageLocation: StorageLocation
    @State private var imageData: Data?
    @State private var showingUnitExplanation = false
    
    init(item: FoodItem) {
        self.item = item
        self._name = State(initialValue: item.name)
        self._selectedCategory = State(initialValue: item.category)
        
        // Convert stored base units back to user-friendly units for display
        var displayQuantity = item.quantity
        var displayUnit = item.unit
        
        // Convert base units to more user-friendly units for editing
        if item.unit == "g" && item.quantity >= 1000 {
            displayQuantity = Int(Double(item.quantity) / 1000.0)
            displayUnit = "kg"
        } else if item.unit == "mL" && item.quantity >= 1000 {
            displayQuantity = Int(Double(item.quantity) / 1000.0)
            displayUnit = "L"
        }
        
        self._quantity = State(initialValue: displayQuantity)
        self._selectedUnit = State(initialValue: displayUnit)
        self._purchaseDate = State(initialValue: item.purchaseDate)
        self._expirationDate = State(initialValue: item.expirationDate)
        self._hasExpirationDate = State(initialValue: item.expirationDate != nil)
        self._stockAlertEnabled = State(initialValue: item.stockAlertEnabled)
        self._selectedEmoji = State(initialValue: item.specificEmoji)
        self._storageLocation = State(initialValue: item.safeStorageLocation)
        self._imageData = State(initialValue: item.imageData)
        
        // 计算推荐的存储位置
        let recommended = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: item.name, category: item.category)
        self._recommendedStorageLocation = State(initialValue: recommended)
    }
    
    private var availableUnits: [(String, String)] {
        let itemUnit = FoodItem.defaultUnit
        
        switch selectedCategory {
        case .dairy, .beverages:
            return [
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized),
                ("gal", "unit.gal".localized),
                ("cups", "unit.cups".localized),
                ("tbsp", "unit.tbsp".localized),
                ("tsp", "unit.tsp".localized),
                (itemUnit, "unit.item".localized)
            ]
        case .eggs:
            return [
                (itemUnit, "unit.item".localized)
            ]
        case .meat, .seafood, .vegetables, .fruits:
            return [
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                (itemUnit, "unit.item".localized)
            ]
        case .grains, .canned, .snacks:
            return [
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                (itemUnit, "unit.item".localized)
            ]
        case .condiments:
            return [
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized),
                ("g", "unit.g".localized),
                ("tbsp", "unit.tbsp".localized),
                ("tsp", "unit.tsp".localized),
                (itemUnit, "unit.item".localized)
            ]
        case .frozen:
            return [
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                (itemUnit, "unit.item".localized)
            ]
        case .other:
            return [
                (itemUnit, "unit.item".localized),
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized),
                ("cups", "unit.cups".localized),
                ("gal", "unit.gal".localized)
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("food.details.name".localized) {
                    TextField("food.details.name".localized, text: $name)
                        .onChange(of: name) { _, _ in
                            updateRecommendedStorage()
                        }
                    
                    // Emoji选择器
                    HStack {
                        Text("voice.edit.icon".localized)
                        Spacer()
                        Button(action: {
                            showingEmojiPicker = true
                        }) {
                            HStack(spacing: 8) {
                                if let emoji = selectedEmoji {
                                    Text(emoji)
                                        .font(.title2)
                                } else {
                                    Text(selectedCategory.icon)
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    HStack {
                        Text("food.details.category".localized)
                        Spacer()
                        Picker("", selection: $selectedCategory) {
                            ForEach(FoodCategory.allCases, id: \.self) { category in
                                Text("\(category.icon) \(category.localizedName)")
                                    .tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedCategory) { _, _ in
                            // Reset unit when category changes if current unit is not available
                            if !availableUnits.contains(where: { $0.0 == selectedUnit }) {
                                selectedUnit = availableUnits.first?.0 ?? FoodItem.defaultUnit
                            }
                            // Update recommended storage location
                            updateRecommendedStorage()
                        }
                    }
                }
                
                Section("food.photo".localized) {
                    PhotoCardView(imageData: $imageData)
                }
                
                Section("food.details.quantity".localized) {
                    HStack {
                        Text("food.details.quantity".localized)
                        Spacer()
                        HStack(spacing: 8) {
                            TextField("1", value: $quantity, format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                            
                            Picker("", selection: $selectedUnit) {
                                ForEach(availableUnits, id: \.0) { unit in
                                    Text(unit.1).tag(unit.0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    // 单位转换说明
                    if let explanation = UnitDisplayHelper.getConversionExplanation(quantity: Double(quantity), unit: selectedUnit) {
                        HStack {
                            Button(action: {
                                showingUnitExplanation = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text(explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        .alert("unit.conversion.explanation".localized, isPresented: $showingUnitExplanation) {
                            Button("common.done".localized, role: .cancel) { }
                        } message: {
                            Text("unit.conversion.detail.message".localized)
                        }
                    }
                    
                    // 单位指导提示
                    if UnitDisplayHelper.needsUnitGuidance(name: name, unit: selectedUnit, quantity: Double(quantity)) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("unit.guidance.message".localized)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                
                Section("add.food.dates.section".localized) {
                    DatePicker("food.details.purchase.date".localized, selection: $purchaseDate, displayedComponents: .date)
                    
                    Toggle("add.food.has.expiration".localized, isOn: $hasExpirationDate)
                    
                    if hasExpirationDate {
                        DatePicker("food.details.expiration.date".localized, selection: Binding(
                            get: { expirationDate ?? Date() },
                            set: { expirationDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section("storage.location".localized) {
                    // 推荐的存储位置提示
                    if storageLocation != recommendedStorageLocation {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("storage.recommended".localized + ": \(recommendedStorageLocation.localizedName)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("storage.recommendation.based.on".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("storage.use.recommended".localized) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    storageLocation = recommendedStorageLocation
                                    updateExpirationDateForStorage()
                                }
                                print("[FoodDetailView] Storage location updated to: \(storageLocation.localizedName)")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // 存储位置选择器
                    HStack {
                        Text("storage.location".localized)
                        Spacer()
                        Picker("", selection: $storageLocation) {
                            ForEach(StorageLocation.allCases, id: \.self) { location in
                                Text("\(location.icon) \(location.localizedName)").tag(location)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: storageLocation) { _, _ in
                            updateExpirationDateForStorage()
                        }
                    }
                    
                    // 存储位置描述
                    Text(storageLocation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Toggle("food.details.stock.alert".localized, isOn: $stockAlertEnabled)
                        .help("food.details.stock.alert.help".localized)
                }
                
                Section {
                    Button("food.details.delete".localized) {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("food.details.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Ensure the selected unit is valid for the current category
                if !availableUnits.contains(where: { $0.0 == selectedUnit }) {
                    selectedUnit = availableUnits.first?.0 ?? FoodItem.defaultUnit
                }
            }
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { saveChanges() },
                saveEnabled: !name.isEmpty && quantity > 0,
                hasInput: !name.isEmpty
            )
            .alert("food.details.delete".localized, isPresented: $showingDeleteAlert) {
                Button("food.details.delete".localized, role: .destructive) {
                    deleteItem()
                }
                Button("food.details.cancel".localized, role: .cancel) { }
            } message: {
                Text("food.details.delete.confirm".localized)
            }
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPicker(selectedEmoji: $selectedEmoji)
                    
            }
        }
    }
    
    private func saveChanges() {
        var finalQuantity = quantity
        var finalUnit = selectedUnit
        
        // Convert to standardized base units (g/mL/pcs) - same logic as shopping list
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
        
        // Check if quantity has changed and record the adjustment
        let oldQuantity = item.quantity
        let quantityChanged = oldQuantity != finalQuantity
        
        // Check if purchase date has changed
        let oldPurchaseDate = item.purchaseDate
        let purchaseDateChanged = oldPurchaseDate != purchaseDate
        
        item.name = name
        item.category = selectedCategory
        item.quantity = finalQuantity
        item.unit = finalUnit
        item.purchaseDate = purchaseDate
        item.expirationDate = hasExpirationDate ? expirationDate : nil
        item.stockAlertEnabled = stockAlertEnabled
        item.specificEmoji = selectedEmoji
        item.storageLocation = storageLocation
        item.imageData = imageData
        
        do {
            try modelContext.save()
            
            // Record quantity adjustment in history if quantity changed
            if quantityChanged {
                Task {
                    await HistoryRecordService.shared.recordQuantityAdjustment(
                        itemName: name,
                        oldQuantity: Double(oldQuantity),
                        newQuantity: Double(finalQuantity),
                        unit: finalUnit,
                        category: selectedCategory,
                        in: modelContext
                    )
                }
            }
            
            // Update purchase record date if purchase date changed
            if purchaseDateChanged {
                Task {
                    await HistoryRecordService.shared.updatePurchaseRecordDate(
                        itemName: name,
                        oldPurchaseDate: oldPurchaseDate,
                        newPurchaseDate: purchaseDate,
                        in: modelContext
                    )
                }
            }
            
            // 编辑食品后刷新通知
            Task { @MainActor in
                NotificationManager.shared.refreshNotifications()
            }
        } catch {
            print("Failed to save changes: \(error)")
        }
        
        dismiss()
    }
    
    private func deleteItem() {
        withAnimation {
            // Record deletion in history if item is expired
            let isExpired = item.isExpired
            
            // Store item details before deletion
            let itemName = item.name
            let itemQuantity = Double(item.quantity)
            let itemUnit = item.unit
            let itemCategory = item.category
            
            // If the item is the last one in its group, delete the entire group.
            // SwiftData's cascade rule will handle deleting the item.
            if let group = item.group, group.items.count == 1 {
                modelContext.delete(group)
            } else {
                // Otherwise, just delete the item. SwiftData will handle updating the relationship.
                modelContext.delete(item)
            }
            
            do {
                try modelContext.save()
                
                // Record expiration in history if item was expired
                if isExpired {
                    Task {
                        await HistoryRecordService.shared.recordExpiration(
                            itemName: itemName,
                            quantity: itemQuantity,
                            unit: itemUnit,
                            category: itemCategory,
                            in: modelContext,
                            notes: "manually.deleted.expired.item".localized
                        )
                    }
                }
                
                // 删除食品后刷新通知
                Task { @MainActor in
                    NotificationManager.shared.refreshNotifications()
                }
                
                dismiss()
            } catch {
                print("Failed to delete item or group: \(error)")
                // Attempt to dismiss anyway
                dismiss()
            }
        }
    }
    
    private func updateExpirationDateForStorage() {
        let shelfLifeDays = StorageLocationRecommendationEngine.shared.getShelfLifeDays(
            for: name, 
            category: selectedCategory, 
            storageLocation: storageLocation
        )
        expirationDate = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: purchaseDate)
        hasExpirationDate = true
    }
    
    private func updateRecommendedStorage() {
        let newRecommended = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: name, category: selectedCategory)
        recommendedStorageLocation = newRecommended
    }
}

#Preview {
    let item = FoodItem(name: "牛奶", category: .dairy, quantity: 2, unit: "L", storageLocation: .refrigerator)
    
    return FoodDetailView(item: item)
        .modelContainer(for: FoodItem.self, inMemory: true)
        
}