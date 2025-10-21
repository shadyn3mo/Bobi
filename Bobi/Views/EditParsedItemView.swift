import SwiftUI

struct EditParsedItemView: View {
    @Binding var item: ParsedFoodItem
    @Environment(\.dismiss) private var dismiss
    @State private var showingEmojiPicker = false
    @State private var showingUnitExplanation = false
    
    private var availableUnits: [(String, String)] {
        switch item.category {
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
                ("L", "unit.L".localized),
                ("cups", "unit.cups".localized),
                ("gal", "unit.gal".localized)
            ]
        }
    }
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("voice.edit.basic".localized)) {
                    TextField("voice.edit.name".localized, text: $item.name)
                    
                    // Emoji选择器
                    HStack {
                        Text("voice.edit.icon".localized)
                        Spacer()
                        Button(action: {
                            showingEmojiPicker = true
                        }) {
                            HStack {
                                Text(item.specificEmoji ?? item.category.icon)
                                    .font(.title2)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Picker("voice.edit.category".localized, selection: $item.category) {
                        ForEach(FoodCategory.allCases, id: \.self) { category in
                            Text("\(category.icon) \(category.localizedName)").tag(category)
                        }
                    }
                    .onChange(of: item.category) { _, _ in
                        // Reset unit when category changes
                        item.unit = availableUnits.first?.0 ?? FoodItem.defaultUnit
                    }
                }
                
                Section(header: Text("voice.edit.quantity".localized)) {
                    HStack {
                        Text("voice.edit.quantity".localized)
                        Spacer()
                        TextField("1", value: $item.quantity, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Picker("", selection: $item.unit) {
                            ForEach(availableUnits, id: \.0) { unit in
                                Text(unit.1).tag(unit.0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                    
                    // 单位转换说明
                    if let explanation = UnitDisplayHelper.getConversionExplanation(quantity: Double(item.quantity), unit: item.unit) {
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
                    if UnitDisplayHelper.needsUnitGuidance(name: item.name, unit: item.unit, quantity: Double(item.quantity)) {
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
                
                Section(header: Text("storage.location".localized)) {
                    // 推荐的存储位置提示
                    if item.storageLocation != item.recommendedStorageLocation {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("storage.recommended".localized + ": \(item.recommendedStorageLocation.localizedName)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("storage.recommendation.based.on".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("storage.use.recommended".localized) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    // 切换存储位置并重新计算过期日期
                                    item.storageLocation = item.recommendedStorageLocation
                                    
                                    // 重新计算过期日期
                                    let shelfLifeDays = StorageLocationRecommendationEngine.shared.getShelfLifeDays(
                                        for: item.name, 
                                        category: item.category, 
                                        storageLocation: item.storageLocation
                                    )
                                    item.estimatedExpirationDate = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: item.purchaseDate)
                                }
                                print("[EditParsedItemView] Storage location updated to: \(item.storageLocation.localizedName)")
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
                        Picker("", selection: Binding(
                            get: { item.storageLocation },
                            set: { newLocation in
                                item.storageLocation = newLocation
                                
                                // 当存储位置改变时，重新计算过期日期
                                let shelfLifeDays = StorageLocationRecommendationEngine.shared.getShelfLifeDays(
                                    for: item.name, 
                                    category: item.category, 
                                    storageLocation: newLocation
                                )
                                item.estimatedExpirationDate = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: item.purchaseDate)
                            }
                        )) {
                            ForEach(StorageLocation.allCases, id: \.self) { location in
                                Text("\(location.icon) \(location.localizedName)").tag(location)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // 存储位置描述
                    Text(item.storageLocation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("food.photo".localized)) {
                    PhotoCardView(imageData: $item.imageData)
                }
                
                Section(header: Text("voice.edit.expiration".localized)) {
                    DatePicker("food.details.purchase.date".localized, selection: $item.purchaseDate, displayedComponents: .date)
                    
                    Toggle(isOn: Binding(
                        get: { item.estimatedExpirationDate != nil },
                        set: { hasExpiration in
                            if hasExpiration {
                                item.estimatedExpirationDate = Calendar.current.date(byAdding: .day, value: 7, to: item.purchaseDate) ?? Date()
                            } else {
                                item.estimatedExpirationDate = nil
                            }
                        }
                    )) {
                        Text("add.food.has.expiration".localized)
                    }
                    
                    if item.estimatedExpirationDate != nil {
                        DatePicker(
                            "food.details.expiration.date".localized,
                            selection: Binding(
                                get: { item.estimatedExpirationDate ?? Date() },
                                set: { item.estimatedExpirationDate = $0 }
                            ),
                            in: item.purchaseDate...,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("voice.edit.title".localized)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { dismiss() },
                saveEnabled: true,
                hasInput: !item.name.isEmpty
            )
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPicker(selectedEmoji: $item.specificEmoji)
        }
    }
} 