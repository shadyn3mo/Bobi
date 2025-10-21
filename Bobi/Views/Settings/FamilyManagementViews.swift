import SwiftUI
import SwiftData

// MARK: - Family Banner View
struct FamilyBannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var familyProfiles: [FamilyProfile]
    @State private var showingFamilyManagement = false
    @State private var showingFamilySetup = false
    
    var currentFamily: FamilyProfile? {
        familyProfiles.first
    }
    
    var body: some View {
        Button(action: {
            if currentFamily?.members.isEmpty ?? true {
                showingFamilySetup = true
            } else {
                showingFamilyManagement = true
            }
        }) {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "house.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("family.management.my.family".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(familyDisplayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if let family = currentFamily, !family.members.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FamilyQuickStatView(
                                icon: "person.3.fill",
                                count: family.members.count,
                                label: "family.management.total.members".localized,
                                color: .blue
                            )
                            
                            FamilyQuickStatView(
                                icon: "figure.and.child.holdinghands",
                                count: family.members.filter { $0.ageCategory == .baby }.count,
                                label: "family.management.babies".localized,
                                color: .pink
                            )
                            
                            FamilyQuickStatView(
                                icon: "figure.child",
                                count: family.members.filter { $0.ageCategory == .child }.count,
                                label: "family.management.children".localized,
                                color: .green
                            )
                            
                            FamilyQuickStatView(
                                icon: "person.fill",
                                count: family.members.filter { $0.ageCategory == .youth }.count,
                                label: "family.management.youth".localized,
                                color: .blue
                            )
                            
                            FamilyQuickStatView(
                                icon: "person.crop.square.fill",
                                count: family.members.filter { $0.ageCategory == .adult }.count,
                                label: "family.management.adults".localized,
                                color: .orange
                            )
                            
                            FamilyQuickStatView(
                                icon: "figure.walk",
                                count: family.members.filter { $0.ageCategory == .senior }.count,
                                label: "family.management.seniors".localized,
                                color: .purple
                            )
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("family.management.tap.add.members".localized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray6), lineWidth: 0.3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingFamilyManagement) {
            FamilyManagementView()
        }
        .sheet(isPresented: $showingFamilySetup) {
            FamilySetupPromptView()
        }
        .onAppear {
            if familyProfiles.isEmpty {
                setupDefaultFamily()
            }
        }
    }
    
    private var familyDisplayName: String {
        if let familyName = currentFamily?.name, !familyName.isEmpty {
            let defaultName = "family.management.my.family".localized
            if familyName == defaultName {
                return familyName
            } else {
                return "\(familyName)" + "family.possessive.suffix".localized
            }
        } else {
            return "family.management.unnamed.family".localized
        }
    }
    
    private func setupDefaultFamily() {
        cleanupDuplicateFamilies()
        
        if familyProfiles.isEmpty {
            let defaultName = "family.management.my.family".localized
            let defaultFamily = FamilyProfile(name: defaultName)
            modelContext.insert(defaultFamily)
            
            do {
                try modelContext.save()
                print("👨‍👩‍👧‍👦 [FamilyManagement] Created default family profile with name: '\(defaultName)'")
            } catch {
                print("❌ [FamilyManagement] Failed to create default family: \(error)")
            }
        } else {
            // 检查现有family是否有有效名称
            for family in familyProfiles {
                if family.name.isEmpty {
                    let defaultName = "family.management.my.family".localized
                    family.name = defaultName
                    print("🔧 [FamilyManagement] Fixed empty family name, set to: '\(defaultName)'")
                    
                    do {
                        try modelContext.save()
                        print("✅ [FamilyManagement] Successfully updated empty family name")
                    } catch {
                        print("❌ [FamilyManagement] Failed to update family name: \(error)")
                    }
                }
            }
        }
    }
    
    private func cleanupDuplicateFamilies() {
        if familyProfiles.count > 1 {
            print("🧹 [FamilyManagement] Found \(familyProfiles.count) family profiles, cleaning up duplicates...")
            
            let primaryFamily = familyProfiles[0]
            var allMembers: [FamilyMember] = primaryFamily.members
            
            for i in 1..<familyProfiles.count {
                let duplicateFamily = familyProfiles[i]
                allMembers.append(contentsOf: duplicateFamily.members)
                modelContext.delete(duplicateFamily)
            }
            
            primaryFamily.members = allMembers
            
            do {
                try modelContext.save()
                print("✅ [FamilyManagement] Cleaned up duplicate families, merged \(allMembers.count) members")
            } catch {
                print("❌ [FamilyManagement] Failed to cleanup families: \(error)")
            }
        }
    }
}

// MARK: - Family Quick Stat View
struct FamilyQuickStatView: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Family Setup Prompt View
struct FamilySetupPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingFamilyManagement = false
    @State private var localizationManager = LocalizationManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Query private var familyProfiles: [FamilyProfile]
    
    private var familyMembers: [FamilyMember] {
        familyProfiles.first?.members ?? []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image("family_welcome")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 110, height: 110)
                }
                
                // Title
                Text(RecipeSetupLocalizations.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(RecipeSetupLocalizations.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                // Benefits
                VStack(alignment: .leading, spacing: 16) {
                    BenefitRow(
                        icon: "sparkles",
                        text: "family.setup.benefit.nutrition".localized,
                        color: .orange
                    )
                    
                    BenefitRow(
                        icon: "chart.pie.fill",
                        text: "family.setup.benefit.portions".localized,
                        color: .blue
                    )
                    
                    BenefitRow(
                        icon: "heart.fill",
                        text: "family.setup.benefit.family".localized,
                        color: .red
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        setupDefaultFamilyIfNeeded()
                        showingFamilyManagement = true
                    }) {
                        Text(RecipeSetupLocalizations.setupNow)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text(RecipeSetupLocalizations.setupLater)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 30)
            }
            .standardCancelToolbar(onCancel: { dismiss() })
        }
        .sheet(isPresented: $showingFamilyManagement) {
            FamilyManagementView()
        }
        .onChange(of: showingFamilyManagement) { oldValue, newValue in
            if !newValue && !familyMembers.isEmpty {
                dismiss()
            }
        }
    }
    
    private func setupDefaultFamilyIfNeeded() {
        // 如果没有家庭配置文件，创建一个默认的
        if familyProfiles.isEmpty {
            let defaultName = "family.management.my.family".localized
            let defaultFamily = FamilyProfile(name: defaultName)
            modelContext.insert(defaultFamily)
            
            do {
                try modelContext.save()
                print("👨‍👩‍👧‍👦 [FamilySetupPrompt] Created default family profile with name: '\(defaultName)'")
            } catch {
                print("❌ [FamilySetupPrompt] Failed to create default family: \(error)")
            }
        } else {
            // 检查现有family是否有有效名称
            for family in familyProfiles {
                if family.name.isEmpty {
                    let defaultName = "family.management.my.family".localized
                    family.name = defaultName
                    print("🔧 [FamilySetupPrompt] Fixed empty family name, set to: '\(defaultName)'")
                    
                    do {
                        try modelContext.save()
                        print("✅ [FamilySetupPrompt] Successfully updated empty family name")
                    } catch {
                        print("❌ [FamilySetupPrompt] Failed to update family name: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Family Management Main View
struct FamilyManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var familyProfiles: [FamilyProfile]
    @State private var showingAddMember = false
    @State private var editingMember: FamilyMember?
    @State private var familyName = ""
    
    private var currentFamily: FamilyProfile? {
        familyProfiles.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Family Name Section
                Section {
                    HStack {
                        Text("family.management.family.name".localized)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        TextField("family.management.enter.family.name".localized, text: $familyName)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                }
                
                // Family Members Section
                Section {
                    if let family = currentFamily, !family.members.isEmpty {
                        ForEach(family.members.sorted { $0.name < $1.name }, id: \.id) { member in
                            FamilyMemberRow(member: member) {
                                editingMember = member
                            }
                        }
                        .onDelete(perform: deleteMember)
                    } else {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.secondary)
                            Text("family.management.no.members".localized)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    HStack {
                        Text("family.management.family.members".localized)
                        Spacer()
                        Button(action: { showingAddMember = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Family Statistics
                if let family = currentFamily, !family.members.isEmpty {
                    Section("family.management.family.statistics".localized) {
                        FamilyStatisticsView(family: family)
                    }
                }
            }
            .navigationTitle("family.management.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { 
                    saveFamilyName()
                    dismiss() 
                },
                saveEnabled: true, // 总是允许保存，会使用默认名称作为后备
                hasInput: !familyName.isEmpty
            )
            .sheet(isPresented: $showingAddMember) {
                AddFamilyMemberView()
            }
            .sheet(item: $editingMember) { member in
                EditFamilyMemberView(member: member)
            }
            .onAppear {
                // 确保始终有一个有效的family name
                let defaultName = "family.management.my.family".localized
                familyName = currentFamily?.name ?? defaultName
                
                // 如果当前family没有名称，立即设置默认名称
                if let family = currentFamily, family.name.isEmpty {
                    family.name = defaultName
                    do {
                        try modelContext.save()
                        print("✅ [FamilyManagement] Set default name for existing family")
                    } catch {
                        print("❌ [FamilyManagement] Failed to set default family name: \(error)")
                    }
                }
            }
        }
    }
    
    private func saveFamilyName() {
        guard let family = currentFamily else { 
            print("❌ [FamilyManagement] No current family found to save name")
            return 
        }
        
        // 确保family name不为空，使用默认名称作为后备
        let finalName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        family.name = finalName.isEmpty ? "family.management.my.family".localized : finalName
        
        print("💾 [FamilyManagement] Saving family name: '\(family.name)'")
        
        do {
            try modelContext.save()
            print("✅ [FamilyManagement] Successfully saved family name")
        } catch {
            print("❌ [FamilyManagement] Failed to save family name: \(error)")
        }
    }
    
    private func deleteMember(at offsets: IndexSet) {
        guard let family = currentFamily else { return }
        let sortedMembers = family.members.sorted { $0.name < $1.name }
        
        for index in offsets {
            let member = sortedMembers[index]
            if let memberIndex = family.members.firstIndex(where: { $0.id == member.id }) {
                family.members.remove(at: memberIndex)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("❌ [FamilyManagement] Failed to delete member: \(error)")
        }
    }
}

// MARK: - Family Member Row
struct FamilyMemberRow: View {
    let member: FamilyMember
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(member.gender == .male ? Color.blue.opacity(0.15) : Color.pink.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: member.gender == .male ? "person.fill" : "person.fill")
                        .foregroundColor(member.gender == .male ? .blue : .pink)
                        .font(.system(size: 18))
                }
                
                // Member info
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(member.ageDescription)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text(member.ageCategoryLocalizedName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        if !member.dietaryRestrictions.isEmpty {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text("dietary.restriction.count.\(member.dietaryRestrictions.count)".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Family Statistics View
struct FamilyStatisticsView: View {
    let family: FamilyProfile
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatCard(
                    title: "family.management.total.members".localized,
                    value: "\(family.members.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "family.management.adults".localized,
                    value: "\(family.members.filter { $0.ageCategory == .adult }.count)",
                    color: .orange
                )
            }
            
            HStack(spacing: 20) {
                StatCard(
                    title: "family.management.children".localized,
                    value: "\(family.members.filter { $0.ageCategory == .child }.count)",
                    color: .green
                )
                
                StatCard(
                    title: "family.management.seniors".localized,
                    value: "\(family.members.filter { $0.ageCategory == .senior }.count)",
                    color: .purple
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}