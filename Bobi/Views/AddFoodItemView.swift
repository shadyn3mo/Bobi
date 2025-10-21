import SwiftUI
import SwiftData

struct AddFoodItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    @State private var name = ""
    @State private var selectedCategory = FoodCategory.other
    @State private var quantity = 1
    @State private var unit = FoodItem.defaultUnit
    @State private var purchaseDate = Date()
    @State private var expirationDate: Date?
    @State private var hasExpirationDate = false
    @State private var stockAlertEnabled = false
    @State private var storageLocation: StorageLocation = .refrigerator
    @State private var recommendedStorageLocation: StorageLocation = .refrigerator
    @State private var showingEmojiPicker = false
    @State private var selectedEmoji: String?
    @State private var imageData: Data?
    @State private var showingUnitExplanation = false
    
    private var availableUnits: [(String, String)] {
        switch selectedCategory {
        case .dairy, .beverages:
            return [
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized),
                ("gal", "unit.gal".localized),
                ("cups", "unit.cups".localized),
                ("tbsp", "unit.tbsp".localized),
                ("tsp", "unit.tsp".localized),
                (FoodItem.defaultUnit, "unit.item".localized)
            ]
        case .eggs:
            return [
                (FoodItem.defaultUnit, "unit.item".localized)
            ]
        case .meat, .seafood, .vegetables, .fruits:
            return [
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                (FoodItem.defaultUnit, "unit.item".localized)
            ]
        case .grains, .canned, .snacks:
            return [
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                (FoodItem.defaultUnit, "unit.item".localized)
            ]
        case .condiments:
            return [
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized),
                ("g", "unit.g".localized),
                ("tbsp", "unit.tbsp".localized),
                ("tsp", "unit.tsp".localized),
                (FoodItem.defaultUnit, "unit.item".localized)
            ]
        case .frozen:
            return [
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                (FoodItem.defaultUnit, "unit.item".localized)
            ]
        case .other:
            return [
                (FoodItem.defaultUnit, "unit.item".localized),
                ("g", "unit.g".localized),
                ("kg", "unit.kg".localized),
                ("oz", "unit.oz".localized),
                ("lbs", "unit.lbs".localized),
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized)
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("add.food.basic.info".localized) {
                    TextField("add.food.name.placeholder".localized, text: $name)
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
                        Text("add.food.category".localized)
                        Spacer()
                        Picker("", selection: $selectedCategory) {
                            ForEach(FoodCategory.allCases, id: \.self) { category in
                                Text("\(category.icon) \(category.localizedName)")
                                    .tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedCategory) { _, _ in
                            // Reset unit when category changes
                            unit = availableUnits.first?.0 ?? FoodItem.defaultUnit
                            // Update recommended storage location
                            updateRecommendedStorage()
                        }
                    }
                }
                
                Section("food.photo".localized) {
                    PhotoCardView(imageData: $imageData)
                }
                
                Section("add.food.quantity.section".localized) {
                    HStack {
                        Text("add.food.quantity".localized)
                        Spacer()
                        TextField("1", value: $quantity, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Picker("", selection: $unit) {
                            ForEach(availableUnits, id: \.0) { unit in
                                Text(unit.1).tag(unit.0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                    
                    // 单位转换说明
                    if let explanation = UnitDisplayHelper.getConversionExplanation(quantity: Double(quantity), unit: unit) {
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
                    if UnitDisplayHelper.needsUnitGuidance(name: name, unit: unit, quantity: Double(quantity)) {
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
                    DatePicker("add.food.purchase.date".localized, selection: $purchaseDate, displayedComponents: .date)
                    
                    Toggle("add.food.has.expiration".localized, isOn: $hasExpirationDate)
                        .onChange(of: hasExpirationDate) { _, newValue in
                            if newValue {
                                updateExpirationDateForStorage()
                            }
                        }
                    
                    if hasExpirationDate {
                        DatePicker("add.food.expiration.date".localized, selection: Binding(
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
                                print("[AddFoodItemView] Storage location updated to: \(storageLocation.localizedName)")
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
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("add.food.title".localized)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { saveItem() },
                saveEnabled: !name.isEmpty,
                hasInput: !name.isEmpty
            )
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPicker(selectedEmoji: $selectedEmoji)
            }
        }
    }
    
    private func saveItem() {
        var finalQuantity = quantity
        var finalUnit = unit
        
        // 单位转换：统一转换为标准单位(g/mL/个)
        if unit == "lbs" || unit == "磅" {
            finalQuantity = Int(Double(quantity) * 453.592)
            finalUnit = "g"
        } else if unit == "oz" || unit == "盎司" {
            finalQuantity = Int(Double(quantity) * 28.3495)
            finalUnit = "g"
        } else if unit == "kg" || unit == "公斤" {
            finalQuantity = Int(Double(quantity) * 1000)
            finalUnit = "g"
        } else if unit == "L" || unit == "升" {
            finalQuantity = Int(Double(quantity) * 1000)
            finalUnit = "mL"
        } else if unit == "gal" || unit == "加仑" {
            finalQuantity = Int(Double(quantity) * 3785)
            finalUnit = "mL"
        } else if unit == "cups" || unit == "杯" {
            finalQuantity = Int(Double(quantity) * 240)
            finalUnit = "mL"
        } else if unit == "tbsp" || unit == "大勺" {
            finalQuantity = Int(Double(quantity) * 15)
            finalUnit = "mL"
        } else if unit == "tsp" || unit == "小勺" {
            finalQuantity = Int(Double(quantity) * 5)
            finalUnit = "mL"
        }
        
        let newItem = FoodItem(
            name: name,
            purchaseDate: purchaseDate,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            category: selectedCategory,
            quantity: finalQuantity,
            unit: finalUnit,
            stockAlertEnabled: stockAlertEnabled,
            specificEmoji: selectedEmoji,
            storageLocation: storageLocation
        )
        
        // 设置图片数据
        if let imageData = imageData {
            newItem.imageData = imageData
        }
        
        // 自动归类到合适的组
        let group = FoodGroupManager.shared.findOrCreateGroup(for: newItem, in: modelContext)
        newItem.group = group
        group.addItem(newItem)
        
        print("Creating new item: \(newItem.name) with ID: \(newItem.id)")
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            print("Successfully saved item: \(newItem.name)")
            
            // 记录购买历史
            Task {
                await HistoryRecordService.shared.recordPurchase(
                    itemName: newItem.name,
                    quantity: Double(newItem.quantity),
                    unit: newItem.unit,
                    category: newItem.category,
                    purchaseDate: newItem.purchaseDate,
                    in: modelContext
                )
            }
            
            // 添加食品后刷新通知
            Task { @MainActor in
                NotificationManager.shared.refreshNotifications()
            }
        } catch {
            print("Failed to save item: \(error)")
        }
        
        dismiss()
    }
    
    private func updateRecommendedStorage() {
        let newRecommended = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: name, category: selectedCategory)
        if recommendedStorageLocation != newRecommended {
            let oldRecommended = recommendedStorageLocation
            recommendedStorageLocation = newRecommended
            // 如果当前存储位置是之前的推荐，则自动更新
            if storageLocation == oldRecommended {
                storageLocation = newRecommended
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
}

#Preview {
    AddFoodItemView()
        .modelContainer(for: FoodItem.self, inMemory: true)
        
}