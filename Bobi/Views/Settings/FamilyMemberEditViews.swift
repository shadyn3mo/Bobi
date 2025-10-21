import SwiftUI
import SwiftData

// MARK: - Add Family Member View
struct AddFamilyMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var familyProfiles: [FamilyProfile]
    @FocusState private var isInputActive: Bool
    
    @State private var name = ""
    @State private var age = 25
    @State private var monthsForBaby = 6
    @State private var gender = Gender.male
    @State private var heightCm = 170.0
    @State private var weightKg = 70.0
    @State private var activityLevel = ActivityLevel.moderate
    @State private var dietaryRestrictions: Set<DietaryRestriction> = []
    @State private var customAllergies: [String] = []
    @State private var newAllergyName = ""
    @State private var showingAddAllergyAlert = false
    
    private var currentFamily: FamilyProfile? {
        familyProfiles.first
    }
    
    private var isBaby: Bool {
        age == 0 && monthsForBaby > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("family.management.basic.information".localized) {
                    HStack {
                        Text("family.management.name".localized)
                        Spacer()
                        TextField("family.management.name".localized, text: $name)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                    }
                    
                    AgePickerComponent(
                        years: $age,
                        months: $monthsForBaby
                    )
                    
                    HStack {
                        Text("family.management.gender".localized)
                        Spacer()
                        Picker("", selection: $gender) {
                            Text(Gender.male.localizedName).tag(Gender.male)
                            Text(Gender.female.localizedName).tag(Gender.female)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                    
                    if !isBaby {
                        HStack {
                            Text("family.management.height".localized)
                            Spacer()
                            Text(String(format: "%.0f cm", heightCm))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $heightCm, in: 100...220, step: 1)
                        
                        HStack {
                            Text("family.management.weight".localized)
                            Spacer()
                            Text(String(format: "%.0f kg", weightKg))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $weightKg, in: 20...150, step: 1)
                        
                        HStack {
                            Text("family.management.activity.level".localized)
                            Spacer()
                            Picker("", selection: $activityLevel) {
                                ForEach(ActivityLevel.allCases, id: \.self) { level in
                                    Text(level.localizedName).tag(level)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                
                // 根据是否为婴儿显示不同的饮食限制选项
                ForEach(DietaryRestrictionCategory.allCases, id: \.self) { category in
                    // 婴儿只显示过敏信息，非婴儿显示所有类别
                    let shouldShowCategory = isBaby ? category == .allergy : true
                    
                    if shouldShowCategory {
                        let restrictionsInCategory = DietaryRestriction.allCases.filter { $0.category == category }
                        if !restrictionsInCategory.isEmpty {
                            Section {
                                ForEach(restrictionsInCategory, id: \.self) { restriction in
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(colorForCategory(category))
                                            .frame(width: 20)
                                        
                                        Text(restriction.localizedName)
                                            .font(.system(size: 15))
                                        
                                        Spacer()
                                        
                                        if dietaryRestrictions.contains(restriction) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(colorForCategory(category))
                                        } else {
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if dietaryRestrictions.contains(restriction) {
                                            dietaryRestrictions.remove(restriction)
                                        } else {
                                            dietaryRestrictions.insert(restriction)
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(colorForCategory(category))
                                    
                                    Text(category.localizedName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colorForCategory(category))
                                }
                            }
                        }
                    }
                }
                
                // 自定义过敏源部分
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        Text("family.custom.allergies.add".localized)
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 [CustomAllergy] Add allergy button tapped via gesture")
                        showingAddAllergyAlert = true
                    }
                    
                    if !customAllergies.isEmpty {
                        ForEach(customAllergies, id: \.self) { allergy in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                
                                Text(allergy)
                                    .font(.system(size: 15))
                                
                                Spacer()
                                
                                Button(action: {
                                    print("🗑️ [CustomAllergy] Delete button tapped for: \(allergy)")
                                    if let index = customAllergies.firstIndex(of: allergy) {
                                        customAllergies.remove(at: index)
                                        print("✅ [CustomAllergy] Successfully removed allergy at index: \(index)")
                                    } else {
                                        print("❌ [CustomAllergy] Could not find allergy in list")
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            Text("family.custom.allergies.empty".localized)
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            
                            Spacer()
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("family.custom.allergies.title".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                } footer: {
                    Text("family.custom.allergies.description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("family.management.add.member".localized)
            .navigationBarTitleDisplayMode(.inline)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { saveMember() },
                saveEnabled: !name.isEmpty,
                hasInput: !name.isEmpty
            )
            .sheet(isPresented: $showingAddAllergyAlert) {
                AddCustomAllergyView(customAllergies: $customAllergies)
            }
        }
    }
    
    private func colorForCategory(_ category: DietaryRestrictionCategory) -> Color {
        switch category {
        case .lifestyle: return .green
        case .dietary: return .blue
        case .health: return .red
        case .religious: return .purple
        case .allergy: return .orange
        }
    }
    
    private func saveMember() {
        guard let family = currentFamily else {
            print("❌ [AddMember] No current family found")
            return
        }
        
        guard !name.isEmpty else {
            print("❌ [AddMember] Name is empty")
            return
        }
        
        print("💾 [AddMember] Creating new member:")
        print("   Name: '\(name)'")
        print("   Age: \(age)")
        print("   Gender: \(gender.rawValue)")
        print("   Is Baby: \(isBaby)")
        print("   Height: \(heightCm) cm")
        print("   Weight: \(weightKg) kg")
        print("   Activity: \(activityLevel.rawValue)")
        print("   Dietary Restrictions: \(Array(dietaryRestrictions).map { $0.rawValue })")
        
        let newMember = FamilyMember(
            name: name,
            age: age,
            gender: gender,
            monthsForBaby: isBaby ? monthsForBaby : 0,
            heightCm: isBaby ? 0 : heightCm,
            weightKg: isBaby ? 0 : weightKg,
            activityLevel: activityLevel,
            dietaryRestrictions: Array(dietaryRestrictions),
            customAllergies: customAllergies
        )
        
        print("✅ [AddMember] New member created with ID: \(newMember.id)")
        
        family.members.append(newMember)
        print("👥 [AddMember] Added to family. Total members: \(family.members.count)")
        
        do {
            try modelContext.save()
            print("✅ [AddMember] Successfully saved new member to database")
            dismiss()
        } catch {
            print("❌ [AddMember] Failed to save new member: \(error)")
            print("   Error details: \(error.localizedDescription)")
            if let detailedError = error as NSError? {
                print("   Error domain: \(detailedError.domain)")
                print("   Error code: \(detailedError.code)")
                print("   User info: \(detailedError.userInfo)")
            }
        }
    }
}

// MARK: - Edit Family Member View
struct EditFamilyMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputActive: Bool
    
    let member: FamilyMember
    
    @State private var name = ""
    @State private var age = 25
    @State private var monthsForBaby = 6
    @State private var gender = Gender.male
    @State private var heightCm = 170.0
    @State private var weightKg = 70.0
    @State private var activityLevel = ActivityLevel.moderate
    @State private var dietaryRestrictions: Set<DietaryRestriction> = []
    @State private var customAllergies: [String] = []
    @State private var newAllergyName = ""
    @State private var showingAddAllergyAlert = false
    
    private var isBaby: Bool {
        age == 0 && monthsForBaby > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("family.management.basic.information".localized) {
                    HStack {
                        Text("family.management.name".localized)
                        Spacer()
                        TextField("family.management.name".localized, text: $name)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                    }
                    
                    AgePickerComponent(
                        years: $age,
                        months: $monthsForBaby
                    )
                    
                    HStack {
                        Text("family.management.gender".localized)
                        Spacer()
                        Picker("", selection: $gender) {
                            Text(Gender.male.localizedName).tag(Gender.male)
                            Text(Gender.female.localizedName).tag(Gender.female)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                    
                    if !isBaby {
                        HStack {
                            Text("family.management.height".localized)
                            Spacer()
                            Text(String(format: "%.0f cm", heightCm))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $heightCm, in: 100...220, step: 1)
                        
                        HStack {
                            Text("family.management.weight".localized)
                            Spacer()
                            Text(String(format: "%.0f kg", weightKg))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $weightKg, in: 20...150, step: 1)
                        
                        HStack {
                            Text("family.management.activity.level".localized)
                            Spacer()
                            Picker("", selection: $activityLevel) {
                                ForEach(ActivityLevel.allCases, id: \.self) { level in
                                    Text(level.localizedName).tag(level)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                
                // 根据是否为婴儿显示不同的饮食限制选项
                ForEach(DietaryRestrictionCategory.allCases, id: \.self) { category in
                    // 婴儿只显示过敏信息，非婴儿显示所有类别
                    let shouldShowCategory = isBaby ? category == .allergy : true
                    
                    if shouldShowCategory {
                        let restrictionsInCategory = DietaryRestriction.allCases.filter { $0.category == category }
                        if !restrictionsInCategory.isEmpty {
                            Section {
                                ForEach(restrictionsInCategory, id: \.self) { restriction in
                                    HStack {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(colorForCategory(category))
                                            .frame(width: 20)
                                        
                                        Text(restriction.localizedName)
                                            .font(.system(size: 15))
                                        
                                        Spacer()
                                        
                                        if dietaryRestrictions.contains(restriction) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(colorForCategory(category))
                                        } else {
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if dietaryRestrictions.contains(restriction) {
                                            dietaryRestrictions.remove(restriction)
                                        } else {
                                            dietaryRestrictions.insert(restriction)
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(colorForCategory(category))
                                    
                                    Text(category.localizedName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colorForCategory(category))
                                }
                            }
                        }
                    }
                }
                
                // 自定义过敏源部分
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        Text("family.custom.allergies.add".localized)
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🔍 [CustomAllergy] Add allergy button tapped via gesture")
                        showingAddAllergyAlert = true
                    }
                    
                    if !customAllergies.isEmpty {
                        ForEach(customAllergies, id: \.self) { allergy in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                
                                Text(allergy)
                                    .font(.system(size: 15))
                                
                                Spacer()
                                
                                Button(action: {
                                    print("🗑️ [CustomAllergy] Delete button tapped for: \(allergy)")
                                    if let index = customAllergies.firstIndex(of: allergy) {
                                        customAllergies.remove(at: index)
                                        print("✅ [CustomAllergy] Successfully removed allergy at index: \(index)")
                                    } else {
                                        print("❌ [CustomAllergy] Could not find allergy in list")
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 20))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.gray)
                                .frame(width: 20)
                            
                            Text("family.custom.allergies.empty".localized)
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            
                            Spacer()
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("family.custom.allergies.title".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                } footer: {
                    Text("family.custom.allergies.description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("family.management.edit.member".localized)
            .navigationBarTitleDisplayMode(.inline)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { saveMember() },
                saveEnabled: !name.isEmpty,
                hasInput: !name.isEmpty
            )
            .sheet(isPresented: $showingAddAllergyAlert) {
                AddCustomAllergyView(customAllergies: $customAllergies)
            }
            .onAppear {
                // 初始化编辑状态
                name = member.name
                age = member.age
                monthsForBaby = member.monthsForBaby
                gender = member.gender
                heightCm = member.heightCm
                weightKg = member.weightKg
                activityLevel = member.activityLevel
                dietaryRestrictions = Set(member.dietaryRestrictions)
                customAllergies = member.customAllergies
            }
        }
    }
    
    private func colorForCategory(_ category: DietaryRestrictionCategory) -> Color {
        switch category {
        case .lifestyle: return .green
        case .dietary: return .blue
        case .health: return .red
        case .religious: return .purple
        case .allergy: return .orange
        }
    }
    
    private func saveMember() {
        guard !name.isEmpty else {
            print("❌ [EditMember] Name is empty")
            return
        }
        
        print("💾 [EditMember] Updating member:")
        print("   Name: '\(name)'")
        print("   Age: \(age)")
        print("   Gender: \(gender.rawValue)")
        print("   Is Baby: \(isBaby)")
        print("   Height: \(heightCm) cm")
        print("   Weight: \(weightKg) kg")
        print("   Activity: \(activityLevel.rawValue)")
        print("   Dietary Restrictions: \(Array(dietaryRestrictions).map { $0.rawValue })")
        
        // 更新成员信息
        member.name = name
        member.age = age
        member.monthsForBaby = isBaby ? monthsForBaby : 0
        member.gender = gender
        member.heightCm = isBaby ? 0 : heightCm
        member.weightKg = isBaby ? 0 : weightKg
        member.activityLevel = activityLevel
        member.dietaryRestrictions = Array(dietaryRestrictions)
        member.customAllergies = customAllergies
        
        do {
            try modelContext.save()
            print("✅ [EditMember] Successfully saved member changes")
            dismiss()
        } catch {
            print("❌ [EditMember] Failed to save member changes: \(error)")
        }
    }
}

// MARK: - Add Custom Allergy View
struct AddCustomAllergyView: View {
    @Binding var customAllergies: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var newAllergyName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("family.custom.allergies.add.title".localized)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("family.custom.allergies.add.description".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("family.custom.allergies.allergy.name".localized)
                            .font(.headline)
                    }
                    
                    TextField("family.custom.allergies.placeholder".localized, text: $newAllergyName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        addAllergy()
                    }) {
                        Text("family.custom.allergies.add.button".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .disabled(newAllergyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("family.management.cancel".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
    private func addAllergy() {
        let trimmedName = newAllergyName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && !customAllergies.contains(trimmedName) {
            customAllergies.append(trimmedName)
            print("✅ [CustomAllergy] Added: \(trimmedName)")
            dismiss()
        }
    }
}