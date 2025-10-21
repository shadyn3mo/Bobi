import SwiftUI
import SwiftData

struct AddShoppingItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    @State private var name = ""
    @State private var selectedCategory = FoodCategory.other
    @State private var selectedUnit = ""
    @State private var minQuantity = 1
    @State private var alertEnabled = true
    @State private var showingUnitExplanation = false
    
    private var availableUnits: [(String, String)] {
        switch selectedCategory {
        case .dairy, .beverages:
            return [
                ("L", "unit.L".localized),
                ("mL", "unit.mL".localized),
                ("item", "unit.item".localized),
                ("cups", "unit.cups".localized)
            ]
        case .eggs:
            return [
                ("item", "unit.item".localized)
            ]
        case .meat, .seafood, .vegetables, .fruits:
            return [
                ("kg", "unit.kg".localized),
                ("g", "unit.g".localized),
                ("lbs", "unit.lbs".localized),
                ("oz", "unit.oz".localized),
                ("item", "unit.item".localized)
            ]
        case .grains, .canned, .snacks:
            return [
                ("kg", "unit.kg".localized),
                ("g", "unit.g".localized),
                ("item", "unit.item".localized)
            ]
        case .condiments:
            return [
                ("mL", "unit.mL".localized),
                ("L", "unit.L".localized),
                ("g", "unit.g".localized),
                ("tbsp", "unit.tbsp".localized),
                ("tsp", "unit.tsp".localized),
                ("item", "unit.item".localized)
            ]
        case .frozen:
            return [
                ("kg", "unit.kg".localized),
                ("g", "unit.g".localized),
                ("item", "unit.item".localized)
            ]
        case .other:
            return [
                ("item", "unit.item".localized),
                ("kg", "unit.kg".localized),
                ("g", "unit.g".localized),
                ("L", "unit.L".localized),
                ("mL", "unit.mL".localized)
            ]
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("shopping.item.name".localized) {
                    TextField("shopping.item.name".localized, text: $name)
                    
                    HStack {
                        Text("shopping.category".localized)
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
                            selectedUnit = availableUnits.first?.0 ?? "item"
                        }
                    }
                }
                
                Section("shopping.threshold".localized) {
                    HStack {
                        Text("shopping.min.quantity".localized)
                        Spacer()
                        TextField("1", value: $minQuantity, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Picker("", selection: $selectedUnit) {
                            ForEach(availableUnits, id: \.0) { unit in
                                Text(unit.1).tag(unit.0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                    
                    // Unit conversion explanation (like food item style)
                    if let explanation = UnitDisplayHelper.getConversionExplanation(quantity: Double(minQuantity), unit: selectedUnit) {
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
                }
                
                Section {
                    Toggle("shopping.enable.alerts".localized, isOn: $alertEnabled)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("shopping.add.item".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedUnit.isEmpty {
                    selectedUnit = availableUnits.first?.0 ?? "item"
                }
            }
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { saveItem() },
                saveEnabled: !name.isEmpty && minQuantity > 0,
                hasInput: !name.isEmpty
            )
        }
    }
    
    private func saveItem() {
        var finalQuantity = minQuantity
        var finalUnit = selectedUnit
        
        // 单位转换：统一转换为标准单位(g/mL/个) - same logic as AddFoodItemView
        if selectedUnit == "lbs" || selectedUnit == "磅" {
            finalQuantity = Int(Double(minQuantity) * 453.592)
            finalUnit = "g"
        } else if selectedUnit == "oz" || selectedUnit == "盎司" {
            finalQuantity = Int(Double(minQuantity) * 28.3495)
            finalUnit = "g"
        } else if selectedUnit == "kg" || selectedUnit == "公斤" {
            finalQuantity = Int(Double(minQuantity) * 1000)
            finalUnit = "g"
        } else if selectedUnit == "L" || selectedUnit == "升" {
            finalQuantity = Int(Double(minQuantity) * 1000)
            finalUnit = "mL"
        } else if selectedUnit == "gal" || selectedUnit == "加仑" {
            finalQuantity = Int(Double(minQuantity) * 3785)
            finalUnit = "mL"
        } else if selectedUnit == "cups" || selectedUnit == "杯" {
            finalQuantity = Int(Double(minQuantity) * 240)
            finalUnit = "mL"
        } else if selectedUnit == "tbsp" || selectedUnit == "大勺" {
            finalQuantity = Int(Double(minQuantity) * 15)
            finalUnit = "mL"
        } else if selectedUnit == "tsp" || selectedUnit == "小勺" {
            finalQuantity = Int(Double(minQuantity) * 5)
            finalUnit = "mL"
        }
        
        let newItem = ShoppingListItem(
            name: name,
            category: selectedCategory,
            unit: finalUnit,
            minQuantity: finalQuantity,
            alertEnabled: alertEnabled
        )
        
        print("Creating new shopping item: \(newItem.name) with ID: \(newItem.id)")
        modelContext.insert(newItem)
        
        do {
            try modelContext.save()
            print("Successfully saved shopping item: \(newItem.name)")
            
            // 注释：移除自动通知刷新，避免触发无关食材的库存检查
            // 只有在实际消耗食材时才进行精准的库存检查
        } catch {
            print("Failed to save shopping item: \(error)")
        }
        
        dismiss()
    }
}

#Preview {
    AddShoppingItemView()
        .modelContainer(for: ShoppingListItem.self, inMemory: true)
        
}