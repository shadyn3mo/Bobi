import SwiftUI
import SwiftData

struct EditFoodGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    let group: FoodGroup
    
    @State private var groupName: String
    @State private var selectedEmoji: String?
    @State private var showingEmojiPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showKeywordChangeAlert = false
    @State private var newCoreKeyword = ""
    
    init(group: FoodGroup) {
        self.group = group
        self._groupName = State(initialValue: group.displayName)
        self._selectedEmoji = State(initialValue: group.customEmoji)
    }
    
    private var coreKeyword: String {
        return group.baseName
    }
    
    private var isValidGroupName: Bool {
        return !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var containsOriginalKeyword: Bool {
        let normalizedGroupName = groupName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCoreKeyword = coreKeyword.lowercased()
        
        return normalizedGroupName.contains(normalizedCoreKeyword)
    }
    
    private var suggestedNewKeyword: String {
        return FoodGroupingService.shared.getBaseFoodName(groupName.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // 当前组信息
                        HStack {
                            Text(selectedEmoji ?? group.displayIcon)
                                .font(.title)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("edit.group.current".localized(with: group.displayName))
                                    .font(.headline)
                                Text("edit.group.core.keyword".localized(with: coreKeyword))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("edit.group.subitems.count".localized(with: group.items.count))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("edit.group.info".localized)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("edit.group.name".localized, text: $groupName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        if !containsOriginalKeyword && isValidGroupName {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("edit.group.keyword.change".localized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                
                                Text("edit.group.keyword.not.contains".localized(with: groupName, coreKeyword))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if suggestedNewKeyword != coreKeyword {
                                    Text("edit.group.suggested.keyword".localized(with: suggestedNewKeyword))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Text("edit.group.keyword.tip".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } header: {
                    Text("edit.group.name.section".localized)
                } footer: {
                    Text("edit.group.name.footer".localized)
                }
                
                Section("edit.group.custom.icon".localized) {
                    HStack {
                        Text("edit.group.icon".localized)
                        Spacer()
                        Button(action: {
                            showingEmojiPicker = true
                        }) {
                            HStack(spacing: 8) {
                                if let emoji = selectedEmoji {
                                    Text(emoji)
                                        .font(.title2)
                                } else {
                                    Text(group.category.icon)
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
                    
                    if selectedEmoji != nil {
                        Button("edit.group.use.default.icon".localized) {
                            selectedEmoji = nil
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("edit.group.subitems.preview".localized) {
                    ForEach(group.items.prefix(3), id: \.id) { item in
                        HStack {
                            Text(item.specificEmoji ?? item.category.icon)
                                .font(.title3)
                            Text(item.name)
                                .font(.body)
                            Spacer()
                            Text(item.formattedQuantityWithUnit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if group.items.count > 3 {
                        Text("edit.group.more.items".localized(with: group.items.count - 3))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("edit.group.title".localized)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { handleSave() },
                saveEnabled: isValidGroupName,
                hasInput: !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .sheet(isPresented: $showingEmojiPicker) {
                EmojiPicker(selectedEmoji: $selectedEmoji)
                    
            }
            .alert("edit.group.save.failed".localized, isPresented: $showAlert) {
                Button("edit.group.ok".localized, role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("edit.group.update.keyword".localized, isPresented: $showKeywordChangeAlert) {
                Button("edit.group.cancel".localized, role: .cancel) { }
                Button("edit.group.update.confirm".localized) {
                    saveChangesWithNewKeyword()
                }
            } message: {
                Text("edit.group.update.keyword.message".localized(with: groupName, newCoreKeyword, coreKeyword, newCoreKeyword))
            }
        }
    }
    
    private func handleSave() {
        if !containsOriginalKeyword && isValidGroupName {
            // 核心关键词发生变化，需要用户确认
            newCoreKeyword = suggestedNewKeyword
            showKeywordChangeAlert = true
        } else {
            // 直接保存
            saveChanges(updateKeyword: false)
        }
    }
    
    private func saveChanges(updateKeyword: Bool = false) {
        if !isValidGroupName {
            alertMessage = "edit.group.name.empty".localized
            showAlert = true
            return
        }
        
        // 保存更改
        group.displayName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        group.customEmoji = selectedEmoji
        group.lastUpdated = Date()
        
        if updateKeyword {
            group.baseName = newCoreKeyword
            print("[EditFoodGroupView] Updated baseName from '\(coreKeyword)' to '\(newCoreKeyword)'")
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "edit.group.save.failed".localized + ": \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func saveChangesWithNewKeyword() {
        saveChanges(updateKeyword: true)
    }
}

#Preview {
    let group = FoodGroup(baseName: "苹果", displayName: "红苹果", category: .fruits)
    
    EditFoodGroupView(group: group)
        .modelContainer(for: [FoodItem.self, FoodGroup.self], inMemory: true)
}