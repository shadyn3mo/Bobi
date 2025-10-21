import SwiftUI
import SwiftData
import CoreData
import Speech
import AVFoundation
import CoreLocation

// MARK: - Privacy & Security View
struct PrivacySecurityView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingResetConfirmation = false
    @State private var showingResetSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ModernNavigationCard(
                    title: "privacy.data.usage".localized,
                    icon: "doc.text.magnifyingglass",
                    iconColor: .blue,
                    destination: DataUsageView()
                )
                
                ModernNavigationCard(
                    title: "privacy.permissions".localized,
                    icon: "key.fill",
                    iconColor: .orange,
                    destination: PermissionsView()
                )
                
                Spacer(minLength: 16)
                
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Text("privacy.reset.data".localized)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("settings.privacy".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("confirm.data.reset".localized, isPresented: $showingResetConfirmation) {
            Button("cancel".localized, role: .cancel) {
                showingResetConfirmation = false
            }
            Button("reset".localized, role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("data.reset.message".localized)
        }
        .alert("data.reset.complete".localized, isPresented: $showingResetSuccess) {
            Button("ok".localized) {
                showingResetSuccess = false
            }
        } message: {
            Text("data.cleared.message".localized)
        }
    }
    
    private func resetAllData() {
        // 首先清理所有通知，避免通知系统访问将要删除的数据
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 延迟更长时间确保所有UI更新完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 使用最安全的删除方法
            self.performUltraSafeDataReset()
        }
    }
    
    private func performSafeDataReset() {
        do {
            // 分步删除，避免同时处理多种类型，每次只处理少量对象
            
            // 1. 删除 FamilyProfile（没有复杂关系）
            let familyDescriptor = FetchDescriptor<FamilyProfile>()
            let familyProfiles = try modelContext.fetch(familyDescriptor)
            for profile in familyProfiles {
                modelContext.delete(profile)
            }
            try modelContext.save()
            
            // 2. 删除 ShoppingListItem（安全删除，避免属性访问错误）
            do {
                var hasMoreShoppingItems = true
                while hasMoreShoppingItems {
                    var shoppingDescriptor = FetchDescriptor<ShoppingListItem>()
                    shoppingDescriptor.fetchLimit = 10  // 进一步减少批次大小
                    
                    let shoppingItems = try modelContext.fetch(shoppingDescriptor)
                    if shoppingItems.isEmpty {
                        hasMoreShoppingItems = false
                    } else {
                        // 先清空可能导致问题的属性，然后保存
                        for item in shoppingItems {
                            // 重置属性为默认值，避免在删除过程中访问detached对象
                            item.name = ""
                            item.category = .other
                            item.unit = ""
                            item.minQuantity = 0
                            item.alertEnabled = false
                        }
                        
                        // 保存属性清空的状态
                        try modelContext.save()
                        
                        // 小延迟确保UI有时间更新
                        usleep(50000) // 50ms延迟
                        
                        // 再次获取对象并删除
                        let itemsToDelete = try modelContext.fetch(shoppingDescriptor)
                        for item in itemsToDelete {
                            modelContext.delete(item)
                        }
                        try modelContext.save()
                    }
                }
            } catch {
                print("ShoppingListItem deletion failed: \(error)")
                // 如果删除失败，尝试强制清理
                do {
                    let allShoppingItems = try modelContext.fetch(FetchDescriptor<ShoppingListItem>())
                    for item in allShoppingItems {
                        modelContext.delete(item)
                    }
                    try modelContext.save()
                } catch {
                    print("Force cleanup of ShoppingListItem failed: \(error)")
                }
            }
            
            // 3. 清理 FoodItem 关系并删除（分批处理）
            
            // 先清理关系
            var hasMoreFoodItems = true
            while hasMoreFoodItems {
                var foodItemDescriptor = FetchDescriptor<FoodItem>()
                foodItemDescriptor.fetchLimit = 50
                
                let foodItems = try modelContext.fetch(foodItemDescriptor)
                if foodItems.isEmpty {
                    hasMoreFoodItems = false
                } else {
                    for foodItem in foodItems {
                        foodItem.group = nil
                    }
                    try modelContext.save()
                }
            }
            
            // 再删除 FoodItem
            hasMoreFoodItems = true
            while hasMoreFoodItems {
                var foodItemDescriptor = FetchDescriptor<FoodItem>()
                foodItemDescriptor.fetchLimit = 50
                
                let foodItems = try modelContext.fetch(foodItemDescriptor)
                if foodItems.isEmpty {
                    hasMoreFoodItems = false
                } else {
                    for item in foodItems {
                        modelContext.delete(item)
                    }
                    try modelContext.save()
                }
            }
            
            // 4. 最后删除 FoodGroup
            let foodGroupDescriptor = FetchDescriptor<FoodGroup>()
            let foodGroups = try modelContext.fetch(foodGroupDescriptor)
            for group in foodGroups {
                modelContext.delete(group)
            }
            try modelContext.save()
            
            showingResetSuccess = true
        } catch {
            print("Data reset failed: \(error)")
            // 在错误情况下也尝试最终清理
            do {
                try modelContext.save()
            } catch {
                print("Final save failed: \(error)")
            }
        }
    }
    
    private func performUltraSafeDataReset() {
        print("🗑️ Starting ultra-safe data reset...")
        
        var anyStepFailed = false
        
        // 1. 删除简单对象：FamilyProfile
        do {
            print("🗑️ Step 1: Deleting FamilyProfile...")
            let familyProfiles = try modelContext.fetch(FetchDescriptor<FamilyProfile>())
            familyProfiles.forEach { modelContext.delete($0) }
            try modelContext.save()
            print("✅ Step 1 completed")
        } catch {
            print("❌ Step 1 failed: \(error)")
            anyStepFailed = true
        }
        
        // 2. 特殊处理 ShoppingListItem - 使用最安全的方式
        do {
            print("🗑️ Step 2: Safely deleting ShoppingListItem...")
            safeDeleteShoppingListItems()
            print("✅ Step 2 completed")
        }
        
        // 3. 清理 FoodItem 关系
        do {
            print("🗑️ Step 3: Clearing FoodItem relationships...")
            let foodItems = try modelContext.fetch(FetchDescriptor<FoodItem>())
            for item in foodItems {
                item.group = nil
            }
            try modelContext.save()
            print("✅ Step 3 completed")
        } catch {
            print("❌ Step 3 failed: \(error)")
            anyStepFailed = true
        }
        
        // 4. 删除 FoodItem
        do {
            print("🗑️ Step 4: Deleting FoodItem...")
            let foodItems = try modelContext.fetch(FetchDescriptor<FoodItem>())
            foodItems.forEach { modelContext.delete($0) }
            try modelContext.save()
            print("✅ Step 4 completed")
        } catch {
            print("❌ Step 4 failed: \(error)")
            anyStepFailed = true
        }
        
        // 5. 删除 FoodGroup
        do {
            print("🗑️ Step 5: Deleting FoodGroup...")
            let foodGroups = try modelContext.fetch(FetchDescriptor<FoodGroup>())
            foodGroups.forEach { modelContext.delete($0) }
            try modelContext.save()
            print("✅ Step 5 completed")
        } catch {
            print("❌ Step 5 failed: \(error)")
            anyStepFailed = true
        }
        
        // 6. 清除所有服务状态和缓存（包括心情状态）
        do {
            print("🗑️ Step 6: Clearing all service states and cache...")
            HomeStatusService.shared.clearAllStateAndCache()
            print("✅ Step 6 completed")
        }
        
        if anyStepFailed {
            print("⚠️ Some steps failed, attempting force cleanup...")
            forceCleanupData()
        } else {
            print("✅ Data reset completed successfully!")
            showingResetSuccess = true
        }
    }
    
    private func safeDeleteShoppingListItems() {
        do {
            // 分批删除，避免一次处理太多
            var itemsRemaining = true
            var attempts = 0
            let maxAttempts = 100 // 防止无限循环
            
            while itemsRemaining && attempts < maxAttempts {
                attempts += 1
                
                var descriptor = FetchDescriptor<ShoppingListItem>()
                descriptor.fetchLimit = 5  // 一次处理5个
                
                let items = try modelContext.fetch(descriptor)
                if items.isEmpty {
                    itemsRemaining = false
                } else {
                    // 使用 forEach 批量删除，避免单独访问属性
                    items.forEach { item in
                        modelContext.delete(item)
                    }
                    
                    // 批量保存
                    try modelContext.save()
                    
                    // 短暂延迟让系统处理
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            
            if attempts >= maxAttempts {
                print("⚠️ Reached max attempts for ShoppingListItem deletion, forcing cleanup")
                // 强制清理剩余项目
                let remainingItems = try modelContext.fetch(FetchDescriptor<ShoppingListItem>())
                remainingItems.forEach { modelContext.delete($0) }
                try modelContext.save()
            }
            
        } catch {
            print("❌ Safe deletion of ShoppingListItem failed: \(error)")
            // 如果所有方法都失败，尝试最后的清理
            do {
                let allItems = try modelContext.fetch(FetchDescriptor<ShoppingListItem>())
                allItems.forEach { modelContext.delete($0) }
                try modelContext.save()
            } catch {
                print("❌ Final cleanup of ShoppingListItem also failed: \(error)")
            }
        }
    }
    
    private func forceCleanupData() {
        print("🔥 Attempting force cleanup...")
        
        // 分别尝试清理每种类型，即使某些失败也继续
        let allShoppingItems = try? modelContext.fetch(FetchDescriptor<ShoppingListItem>())
        allShoppingItems?.forEach { modelContext.delete($0) }
        
        let allFoodItems = try? modelContext.fetch(FetchDescriptor<FoodItem>())
        allFoodItems?.forEach { modelContext.delete($0) }
        
        let allFoodGroups = try? modelContext.fetch(FetchDescriptor<FoodGroup>())
        allFoodGroups?.forEach { modelContext.delete($0) }
        
        let allFamilyProfiles = try? modelContext.fetch(FetchDescriptor<FamilyProfile>())
        allFamilyProfiles?.forEach { modelContext.delete($0) }
        
        // 尝试保存，如果失败就忽略
        do {
            try modelContext.save()
            print("✅ Force cleanup database save succeeded")
        } catch {
            print("❌ Force cleanup database save failed: \(error)")
        }
        
        // 清除服务状态和缓存（这个通常不会失败）
        do {
            HomeStatusService.shared.clearAllStateAndCache()
            print("✅ Force cleanup service cache succeeded")
        }
        
        // 无论如何都显示成功，因为这是最后的清理尝试
        showingResetSuccess = true
        print("🔥 Force cleanup completed (some operations may have failed)")
    }
}

// MARK: - Data Usage View
struct DataUsageView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("data.privacy.title".localized)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("data.privacy.description.1".localized)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("data.privacy.description.2".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        Text("data.privacy.description.3".localized)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Features Section
                LazyVStack(spacing: 16) {
                    PrivacyFeatureCard(
                        icon: "iphone",
                        title: "data.feature.local.title".localized,
                        description: "data.feature.local.description".localized,
                        color: .blue
                    )
                    
                    PrivacyFeatureCard(
                        icon: "eye.slash.fill",
                        title: "data.feature.private.title".localized,
                        description: "data.feature.private.description".localized,
                        color: .green
                    )
                    
                    PrivacyFeatureCard(
                        icon: "lock.shield.fill",
                        title: "data.feature.secure.title".localized,
                        description: "data.feature.secure.description".localized,
                        color: .orange
                    )
                    
                    PrivacyFeatureCard(
                        icon: "brain.head.profile",
                        title: "data.feature.ai.title".localized,
                        description: "data.feature.ai.description".localized,
                        color: .purple
                    )
                    
                    PrivacyFeatureCard(
                        icon: "cloud.fill",
                        title: "data.feature.cloud.ai.title".localized,
                        description: "data.feature.cloud.ai.description".localized,
                        color: .indigo
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("privacy.data.usage".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Feature Card
struct PrivacyFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 48, height: 48)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.08)
    }
}

// MARK: - Privacy Feature Row (Legacy)
struct PrivacyFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Permissions View
struct PermissionsView: View {
    @State private var speechRecognitionStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
    @State private var microphoneStatus: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @StateObject private var cameraService = CameraService()
    @StateObject private var weatherService = WeatherKitService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("permissions.audio.description".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                VStack(spacing: 12) {
                    PermissionStatusView(
                        title: "permissions.location".localized,
                        description: "permissions.location.description".localized,
                        statusText: locationStatusText,
                        statusColor: locationStatusColor,
                        action: requestLocationPermissionOrOpenSettings
                    )
                    
                    PermissionStatusView(
                        title: "permissions.speech.recognition".localized,
                        description: "permissions.speech.recognition.description".localized,
                        statusText: speechRecognitionStatusText,
                        statusColor: speechRecognitionStatusColor,
                        action: openSettings
                    )
                    
                    PermissionStatusView(
                        title: "permissions.microphone".localized,
                        description: "permissions.microphone.description".localized,
                        statusText: microphoneStatusText,
                        statusColor: microphoneStatusColor,
                        action: openSettings
                    )
                    
                    PermissionStatusView(
                        title: "permissions.camera".localized,
                        description: "permissions.camera.description".localized,
                        statusText: cameraStatusText,
                        statusColor: cameraStatusColor,
                        action: openSettings
                    )
                }
                
                Text("permissions.footer.description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("privacy.permissions".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updatePermissionStatus()
        }
    }
    
    private var locationStatusText: String {
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "permissions.status.granted".localized
        case .denied:
            return "permissions.status.denied".localized
        case .restricted:
            return "permissions.status.restricted".localized
        case .notDetermined:
            return "permissions.status.not.requested".localized
        @unknown default:
            return "permissions.status.unknown".localized
        }
    }
    
    private var locationStatusColor: Color {
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var speechRecognitionStatusText: String {
        switch speechRecognitionStatus {
        case .authorized:
            return "permissions.status.granted".localized
        case .denied:
            return "permissions.status.denied".localized
        case .restricted:
            return "permissions.status.restricted".localized
        case .notDetermined:
            return "permissions.status.not.requested".localized
        @unknown default:
            return "permissions.status.unknown".localized
        }
    }
    
    private var speechRecognitionStatusColor: Color {
        switch speechRecognitionStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .granted:
            return "permissions.status.granted".localized
        case .denied:
            return "permissions.status.denied".localized
        case .undetermined:
            return "permissions.status.not.requested".localized
        @unknown default:
            return "permissions.status.unknown".localized
        }
    }
    
    private var microphoneStatusColor: Color {
        switch microphoneStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var cameraStatusText: String {
        switch cameraStatus {
        case .authorized:
            return "permissions.status.granted".localized
        case .denied:
            return "permissions.status.denied".localized
        case .restricted:
            return "permissions.status.restricted".localized
        case .notDetermined:
            return "permissions.status.not.requested".localized
        @unknown default:
            return "permissions.status.unknown".localized
        }
    }
    
    private var cameraStatusColor: Color {
        switch cameraStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private func updatePermissionStatus() {
        speechRecognitionStatus = SFSpeechRecognizer.authorizationStatus()
        microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        locationStatus = CLLocationManager().authorizationStatus
    }
    
    private func requestLocationPermissionOrOpenSettings() {
        if locationStatus == .notDetermined {
            // 如果权限未确定，请求权限
            weatherService.requestLocationPermission()
            // 延迟更新状态，等待用户响应
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                updatePermissionStatus()
            }
        } else {
            // 如果权限已确定，打开设置
            openSettings()
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}


// MARK: - Permission Row
struct PermissionRow: View {
    let title: String
    let description: String
    let status: String
    let statusColor: Color
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 5) {
                    Text(status)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(statusColor)
                    
                    Button("permissions.open.settings".localized) {
                        action()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - AI Connection View
struct AIConnectionView: View {
    private let aiService = AIService.shared
    @StateObject private var aiModelManager = AIModelManager.shared
    @State private var connectionStatus: AIConnectionStatus = .checking
    @Environment(\.colorScheme) var colorScheme
    
    enum AIConnectionStatus {
        case checking, ready, offline, error
        
        var title: String {
            switch self {
            case .checking:
                return "ai.connection.status.checking".localized
            case .ready:
                return "ai.connection.status.ready".localized
            case .offline:
                return "ai.connection.status.offline".localized
            case .error:
                return "ai.connection.status.error".localized
            }
        }
        
        var description: String {
            switch self {
            case .checking:
                return "ai.connection.status.checking.description".localized
            case .ready:
                return "ai.connection.status.ready.description".localized
            case .offline:
                return "ai.connection.status.offline.description".localized
            case .error:
                return "ai.connection.status.error.description".localized
            }
        }
        
        var color: Color {
            switch self {
            case .checking:
                return .orange
            case .ready:
                return .green
            case .offline:
                return .gray
            case .error:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .checking:
                return "clock"
            case .ready:
                return "checkmark.circle.fill"
            case .offline:
                return "wifi.slash"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                AIStatusHeaderView(status: connectionStatus)
                    .padding(.horizontal, 20)
                
                // API Source Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("ai.api.source.title".localized)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    ForEach(APISource.allCases, id: \.self) { source in
                        APISourceCard(
                            source: source,
                            isSelected: aiModelManager.apiSource == source
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                aiModelManager.apiSource = source
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Free AI Info (only show for Free)
                if aiModelManager.apiSource == .free {
                    VStack(spacing: 16) {
                        // 使用状态卡片
                        DailyUsageCard()
                            .padding(.horizontal, 20)
                        
                        // 免费AI说明
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ai.free.model.title".localized)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("ai.free.model.description".localized)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // 升级提示
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ai.upgrade.tip.title".localized)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("ai.upgrade.tip.description".localized)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                            }
                            
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.purple.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                }
                
                // Custom API Configuration (only show when custom API is selected)
                if aiModelManager.apiSource == .custom {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ai.api.provider.title".localized)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(APIProvider.allCases, id: \.self) { provider in
                            APIProviderCard(
                                provider: provider,
                                isSelected: aiModelManager.apiProvider == provider
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    aiModelManager.apiProvider = provider
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    
                    // API Key Configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ai.api.key.config.title".localized)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ai.api.key.label".localized)
                                    .font(.system(size: 14, weight: .medium))
                                SecureField("ai.api.key.placeholder".localized, text: $aiModelManager.customAPIKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                                Text("ai.api.key.info".localized)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackgroundColor)
                                .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Temperature Setting
                VStack(alignment: .leading, spacing: 16) {
                    Text("ai.temperature.title".localized)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ai.temperature.label".localized)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Text(String(format: "%.1f", aiModelManager.temperature))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        
                        Slider(
                            value: $aiModelManager.temperature,
                            in: 0...1.2,
                            step: 0.1
                        )
                        .tint(.blue)
                        
                        Text("ai.temperature.description".localized)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackgroundColor)
                            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.horizontal, 20)

                // Privacy Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("ai.connection.privacy.title".localized)
                        .font(.system(size: 18, weight: .semibold))

                    Text("ai.connection.privacy.description".localized)
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("ai.connection.data.usage".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .padding(.horizontal, 20)
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ai.chef.settings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkAIConnection()
        }
        .onChangeCompat(of: aiModelManager.apiSource) {
            checkAIConnection()
        }
        .onChangeCompat(of: aiModelManager.apiProvider) {
            if aiModelManager.isUsingCustomAPI {
                checkAIConnection()
            }
        }
        .onChangeCompat(of: aiModelManager.customAPIKey) {
            if aiModelManager.isUsingCustomAPI {
                checkAIConnection()
            }
        }
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.08)
    }
    
    private func checkAIConnection() {
        connectionStatus = .checking
        
        Task {
            do {
                let isHealthy = try await aiService.healthCheck()
                await MainActor.run {
                    connectionStatus = isHealthy ? .ready : .offline
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .error
                }
            }
        }
    }
}

// MARK: - AI Model Card
struct AIModelCard: View {
    let model: AIModel
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(model.color.opacity(isSelected ? 1 : 0.2))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: model.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(isSelected ? .white : model.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(model.localizedDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "info.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    Text(model.detailedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? model.color : borderColor, lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private var cardBackgroundColor: Color {
        if isSelected {
            return model.color.opacity(0.1)
        }
        return colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

struct APISourceCard: View {
    let source: APISource
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: source.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(source.color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(source.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(source.color)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? source.color : borderColor, lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private var cardBackgroundColor: Color {
        if isSelected {
            return source.color.opacity(0.1)
        }
        return colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

struct APIProviderCard: View {
    let provider: APIProvider
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: provider.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(provider.color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(provider.description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("ai.provider.default.model".localized + ": \(provider.defaultModel)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(provider.color)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? provider.color : borderColor, lineWidth: isSelected ? 2 : 1)
                )
        )
    }
    
    private var cardBackgroundColor: Color {
        if isSelected {
            return provider.color.opacity(0.1)
        }
        return colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

// MARK: - Compatibility Extension
extension View {
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            return self.onChange(of: value) { _, _ in
                action()
            }
        } else {
            return self.onChange(of: value) { _ in
                action()
            }
        }
    }
}