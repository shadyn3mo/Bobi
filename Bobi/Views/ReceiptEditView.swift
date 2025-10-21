import SwiftUI

struct ReceiptEditView: View {
    @Binding var receipt: ParsedReceipt
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 购买日期选择
                purchaseDateSection
                
                // 识别到的食材列表
                itemsListSection
                
                Spacer()
                
                // 确认按钮
                confirmButton
            }
            .padding()
            .navigationTitle("receipt.edit.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .standardCancelToolbar(onCancel: { dismiss() })
        }
    }
    
    // MARK: - 购买日期选择
    private var purchaseDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("receipt.edit.purchase.info".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            DatePicker("receipt.edit.purchase.date".localized, selection: $receipt.purchaseDate, displayedComponents: .date)
                .datePickerStyle(.compact)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 食材列表
    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("receipt.edit.items.found".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(receipt.items.count) \("receipt.edit.items.count".localized)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            List {
                ForEach(Array(receipt.items.enumerated()), id: \.offset) { index, item in
                    ReceiptItemRow(
                        item: Binding(
                            get: { item },
                            set: { newItem in
                                receipt.items[index] = newItem
                            }
                        ),
                        onDelete: {
                            receipt.items.remove(at: index)
                        }
                    )
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .frame(minHeight: 200)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - 确认按钮
    private var confirmButton: some View {
        Button(action: {
            onSave()
            dismiss()
        }) {
            Text("receipt.edit.confirm.add".localized)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
        .disabled(receipt.items.isEmpty)
    }
    
    // MARK: - Helper Methods
    private func deleteItems(at offsets: IndexSet) {
        receipt.items.remove(atOffsets: offsets)
    }
}

// MARK: - 单个食材行
struct ReceiptItemRow: View {
    @Binding var item: ParsedReceiptItem
    @State private var showingEditSheet = false
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let quantity = item.quantity {
                    Text("\("receipt.item.edit.quantity".localized): \(quantity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let category = item.category {
                    Text("\("receipt.item.edit.category".localized): \(category)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingEditSheet = true
            }) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onDelete()
            } label: {
                Label("common.delete".localized, systemImage: "trash")
            }
            .tint(.red)
        }
        .sheet(isPresented: $showingEditSheet) {
            ReceiptItemEditSheet(item: $item)
        }
    }
}

// MARK: - 食材编辑表单
struct ReceiptItemEditSheet: View {
    @Binding var item: ParsedReceiptItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var quantityValue: Int = 1
    @State private var quantityUnit: String = ""
    @State private var selectedCategory: FoodCategory = .other
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
                ("L", "unit.L".localized),
                ("cups", "unit.cups".localized),
                ("gal", "unit.gal".localized)
            ]
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("voice.edit.basic".localized) {
                    HStack {
                        Text("receipt.item.edit.name".localized)
                        Spacer()
                        TextField("food.details.name".localized, text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("receipt.item.edit.category".localized)
                        Spacer()
                        Picker("", selection: $selectedCategory) {
                            ForEach(FoodCategory.allCases, id: \.self) { category in
                                Text("\(category.icon) \(category.localizedName)")
                                    .tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedCategory) { _, _ in
                            // 当分类改变时，重置单位为第一个可用单位
                            quantityUnit = availableUnits.first?.0 ?? FoodItem.defaultUnit
                        }
                    }
                }
                
                Section("voice.edit.quantity".localized) {
                    HStack {
                        Text("voice.edit.quantity".localized)
                        Spacer()
                        TextField("1", value: $quantityValue, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Picker("", selection: $quantityUnit) {
                            ForEach(availableUnits, id: \.0) { unit in
                                Text(unit.1).tag(unit.0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    // 单位转换说明
                    if let explanation = UnitDisplayHelper.getConversionExplanation(quantity: Double(quantityValue), unit: quantityUnit) {
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
                    if UnitDisplayHelper.needsUnitGuidance(name: name, unit: quantityUnit, quantity: Double(quantityValue)) {
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
            }
            .navigationTitle("voice.edit.title".localized)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: {
                    saveChanges()
                    dismiss()
                }
            )
            .onAppear {
                name = item.name
                
                // 解析数量和单位
                if let quantityString = item.quantity {
                    let (value, unit) = parseQuantityString(quantityString)
                    quantityValue = value
                    quantityUnit = unit
                } else {
                    quantityValue = 1
                    quantityUnit = FoodItem.defaultUnit
                }
                
                // 解析分类 - 优先使用AI识别的分类
                if let categoryString = item.category {
                    selectedCategory = mapAICategoryToFoodCategory(categoryString)
                }
                
                // 确保单位在可用单位列表中
                if !availableUnits.contains(where: { $0.0 == quantityUnit }) {
                    quantityUnit = availableUnits.first?.0 ?? FoodItem.defaultUnit
                }
            }
        }
    }
    
    private func saveChanges() {
        // 单位转换到标准化基础单位 (g/mL/个) - 与其他视图保持一致
        var finalQuantity = quantityValue
        var finalUnit = quantityUnit
        
        if quantityUnit == "lbs" || quantityUnit == "磅" {
            finalQuantity = Int(Double(quantityValue) * 453.592)
            finalUnit = "g"
        } else if quantityUnit == "oz" || quantityUnit == "盎司" {
            finalQuantity = Int(Double(quantityValue) * 28.3495)
            finalUnit = "g"
        } else if quantityUnit == "kg" || quantityUnit == "公斤" {
            finalQuantity = Int(Double(quantityValue) * 1000)
            finalUnit = "g"
        } else if quantityUnit == "L" || quantityUnit == "升" {
            finalQuantity = Int(Double(quantityValue) * 1000)
            finalUnit = "mL"
        } else if quantityUnit == "gal" || quantityUnit == "加仑" {
            finalQuantity = Int(Double(quantityValue) * 3785)
            finalUnit = "mL"
        } else if quantityUnit == "cups" || quantityUnit == "杯" {
            finalQuantity = Int(Double(quantityValue) * 240)
            finalUnit = "mL"
        } else if quantityUnit == "tbsp" || quantityUnit == "大勺" {
            finalQuantity = Int(Double(quantityValue) * 15)
            finalUnit = "mL"
        } else if quantityUnit == "tsp" || quantityUnit == "小勺" {
            finalQuantity = Int(Double(quantityValue) * 5)
            finalUnit = "mL"
        } else if quantityUnit == FoodItem.defaultUnit {
            finalUnit = FoodItem.defaultUnit
        }
        
        print("[ReceiptEditView] 单位转换: \(quantityValue) \(quantityUnit) → \(finalQuantity) \(finalUnit)")
        
        // 构建数量字符串
        let quantityString = formatQuantityString(value: finalQuantity, unit: finalUnit)
        
        item = ParsedReceiptItem(
            name: name.isEmpty ? item.name : name,
            quantity: quantityString,
            category: selectedCategory.localizedName
        )
    }
    
    private func parseQuantityString(_ quantityString: String) -> (Int, String) {
        // 尝试解析"数量 单位"格式，比如"2 个"、"500 g"等
        let components = quantityString.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        
        if components.count >= 2,
           let value = Int(components[0]) {
            let unit = String(components[1])
            return (value, unit)
        } else if let value = Int(quantityString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            // 如果只有数字，使用默认单位
            return (value, FoodItem.defaultUnit)
        } else {
            // 解析失败，返回默认值
            return (1, FoodItem.defaultUnit)
        }
    }
    
    private func formatQuantityString(value: Int, unit: String) -> String {
        if unit == FoodItem.defaultUnit {
            return "\(value) \("unit.item".localized)"
        } else {
            return "\(value) \(unit)"
        }
    }
    
    private func mapAICategoryToFoodCategory(_ aiCategory: String) -> FoodCategory {
        let normalized = aiCategory.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // AI识别的分类映射到标准FoodCategory
        switch normalized {
        case "肉类", "meat":
            return .meat
        case "海鲜", "海产", "seafood", "fish":
            return .seafood
        case "蔬菜", "vegetables":
            return .vegetables
        case "水果", "fruits":
            return .fruits
        case "蛋类", "eggs":
            return .eggs
        case "乳制品", "dairy":
            return .dairy
        case "谷物", "grains":
            return .grains
        case "调料", "调味品", "condiments", "seasoning":
            return .condiments
        case "饮料", "beverages":
            return .beverages
        case "零食", "snacks":
            return .snacks
        case "冷冻", "frozen":
            return .frozen
        case "罐头", "canned":
            return .canned
        case "其他", "other":
            return .other
        default:
            // 如果AI分类无法直接映射，回退到原有的解析逻辑
            return parseCategoryFromString(aiCategory)
        }
    }
    
    private func parseCategoryFromString(_ categoryString: String) -> FoodCategory {
        // 尝试匹配本地化名称
        for category in FoodCategory.allCases {
            if category.localizedName.lowercased() == categoryString.lowercased() {
                return category
            }
        }
        // 如果没有匹配，使用默认的解析逻辑
        return parseCategory(categoryString)
    }
    
    private func parseCategory(_ categoryString: String) -> FoodCategory {
        let lower = categoryString.lowercased()
        
        if lower.contains("牛奶") || lower.contains("奶") || lower.contains("酸奶") ||
           lower.contains("milk") || lower.contains("dairy") || lower.contains("yogurt") || lower.contains("cheese") {
            return .dairy
        } else if lower.contains("肉") || lower.contains("牛") || lower.contains("猪") || lower.contains("鸡") ||
                  lower.contains("meat") || lower.contains("beef") || lower.contains("pork") || lower.contains("chicken") || lower.contains("lamb") {
            return .meat
        } else if lower.contains("菜") || lower.contains("蔬") ||
                  lower.contains("vegetable") || lower.contains("lettuce") || lower.contains("cabbage") || lower.contains("spinach") {
            return .vegetables
        } else if lower.contains("果") || lower.contains("苹果") || lower.contains("香蕉") ||
                  lower.contains("fruit") || lower.contains("apple") || lower.contains("banana") || lower.contains("orange") {
            return .fruits
        } else if lower.contains("蛋") || lower.contains("egg") {
            return .eggs
        } else if lower.contains("鱼") || lower.contains("虾") ||
                  lower.contains("fish") || lower.contains("seafood") || lower.contains("shrimp") || lower.contains("salmon") {
            return .seafood
        } else if lower.contains("饮") || lower.contains("水") || lower.contains("汁") ||
                  lower.contains("drink") || lower.contains("beverage") || lower.contains("juice") || lower.contains("water") {
            return .beverages
        } else if lower.contains("米") || lower.contains("面") || lower.contains("包") ||
                  lower.contains("rice") || lower.contains("noodle") || lower.contains("bread") || lower.contains("grain") {
            return .grains
        } else if lower.contains("罐头") || lower.contains("canned") || lower.contains("can") {
            return .canned
        } else if lower.contains("零食") || lower.contains("饼干") ||
                  lower.contains("snack") || lower.contains("cookie") || lower.contains("chip") {
            return .snacks
        } else if lower.contains("调料") || lower.contains("盐") || lower.contains("糖") ||
                  lower.contains("condiment") || lower.contains("salt") || lower.contains("sugar") || lower.contains("sauce") {
            return .condiments
        } else if lower.contains("冷冻") || lower.contains("frozen") {
            return .frozen
        }
        
        return .other
    }
}

#Preview {
    ReceiptEditView(
        receipt: Binding.constant(ParsedReceipt(
            purchaseDate: Date(),
            items: [
                ParsedReceiptItem(name: "苹果", quantity: "2个", category: "水果"),
                ParsedReceiptItem(name: "牛奶", quantity: "1L", category: "奶制品")
            ]
        )),
        onSave: {}
    )
}