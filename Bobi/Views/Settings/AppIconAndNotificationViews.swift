import SwiftUI
import UIKit

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false
    
    var body: some View {
        List {
            if notificationManager.notificationPermissionStatus != .authorized {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.slash.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            Text("notifications.permission.required".localized)
                                .font(.headline)
                        }
                        Text("notifications.permission.description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            Task {
                                let granted = await notificationManager.requestNotificationPermission()
                                if !granted {
                                    showingPermissionAlert = true
                                }
                            }
                        }) {
                            Text("notifications.enable.button".localized)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $notificationManager.expirationRemindersEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("notifications.expiration.reminder".localized)
                            Text("notifications.expiration.description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // 补货提醒已移除，现在通过采购单管理
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $notificationManager.shoppingListRemindersEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("notifications.shopping.reminder".localized)
                            Text("notifications.shopping.description".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("notifications.types".localized)
            }
            
            if notificationManager.expirationRemindersEnabled || 
               notificationManager.shoppingListRemindersEnabled {
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("notifications.frequency".localized)
                            Spacer()
                            Picker("", selection: $notificationManager.reminderFrequency) {
                                ForEach(ReminderFrequency.allCases, id: \.self) { frequency in
                                    Text(frequency.localizedDescription).tag(frequency)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Text(notificationManager.getEffectiveReminderDescription())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if notificationManager.reminderFrequency != .realtime {
                        if notificationManager.reminderFrequency == .weekly {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("notifications.preferred.weekday".localized)
                                    Spacer()
                                    Picker("", selection: $notificationManager.preferredWeekday) {
                                        ForEach(1...7, id: \.self) { weekday in
                                            Text(notificationManager.getWeekdayName(weekday)).tag(weekday)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                HStack {
                                    Text("notifications.preferred.time".localized)
                                    Spacer()
                                    DatePicker("", selection: $notificationManager.preferredReminderTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                        } else if notificationManager.reminderFrequency == .monthly {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("notifications.preferred.monthday".localized)
                                    Spacer()
                                    Picker("", selection: $notificationManager.preferredMonthDay) {
                                        ForEach(1...31, id: \.self) { day in
                                            Text(String(format: "notification.monthday.format".localized, day)).tag(day)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                if notificationManager.preferredMonthDay > 28 {
                                    Text("notifications.monthday.warning".localized)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                HStack {
                                    Text("notifications.preferred.time".localized)
                                    Spacer()
                                    DatePicker("", selection: $notificationManager.preferredReminderTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                        } else if notificationManager.reminderFrequency == .daily {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("notifications.preferred.time".localized)
                                    Spacer()
                                    DatePicker("", selection: $notificationManager.preferredReminderTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                                
                                Text("notifications.preferred.time.description".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("notifications.schedule".localized)
                }
                
            }
        }
        .navigationTitle("settings.notifications".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("notifications.permission.denied".localized, isPresented: $showingPermissionAlert) {
            Button("settings.open".localized) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("cancel".localized, role: .cancel) { }
        } message: {
            Text("notifications.permission.denied.message".localized)
        }
    }
}


// MARK: - Icon Cache Manager
class IconCacheManager {
    static let shared = IconCacheManager()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 20
        cache.totalCostLimit = 1024 * 1024 * 10 // 10MB
    }
    
    func getIcon(named: String) -> UIImage? {
        if let cachedImage = cache.object(forKey: named as NSString) {
            return cachedImage
        }
        
        if let image = UIImage(named: named) {
            cache.setObject(image, forKey: named as NSString, cost: image.pngData()?.count ?? 0)
            return image
        } else if let image = UIImage(named: "AppIcon\(named)") {
            cache.setObject(image, forKey: named as NSString, cost: image.pngData()?.count ?? 0)
            return image
        }
        
        return nil
    }
}

// MARK: - App Icon Selection View
struct AppIconSelectionView: View {
    @State private var selectedIcon: String = UIApplication.shared.alternateIconName ?? "Default"
    @State private var loadedIcons: Set<String> = []
    
    private let appIcons: [AppIconInfo] = [
        AppIconInfo(name: "Default", displayName: "app.icon.display.name.default".localized, imageName: "AppIcon60x60", isDefault: true),
        AppIconInfo(name: "blue", displayName: "app.icon.display.name.blue".localized, imageName: "blue", isDefault: false),
        AppIconInfo(name: "green", displayName: "app.icon.display.name.green".localized, imageName: "green", isDefault: false),
        AppIconInfo(name: "red", displayName: "app.icon.display.name.red".localized, imageName: "red", isDefault: false),
        AppIconInfo(name: "yellow", displayName: "app.icon.display.name.yellow".localized, imageName: "yellow", isDefault: false),
        AppIconInfo(name: "chicken", displayName: "app.icon.display.name.chicken".localized, imageName: "chicken", isDefault: false),
        AppIconInfo(name: "milk", displayName: "app.icon.display.name.milk".localized, imageName: "milk", isDefault: false),
        AppIconInfo(name: "banana", displayName: "app.icon.display.name.banana".localized, imageName: "banana", isDefault: false),
        AppIconInfo(name: "rainbow", displayName: "app.icon.display.name.rainbow".localized, imageName: "rainbow", isDefault: false),
        AppIconInfo(name: "ice", displayName: "app.icon.display.name.ice".localized, imageName: "ice", isDefault: false)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(appIcons, id: \.name) { iconInfo in
                    AppIconCell(
                        iconInfo: iconInfo,
                        isSelected: selectedIcon == iconInfo.name
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIcon = iconInfo.name
                        }
                        let iconName = iconInfo.name == "Default" ? nil : iconInfo.name
                        DispatchQueue.main.async {
                            setAppIcon(iconName)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("change.app.icon".localized)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            selectedIcon = UIApplication.shared.alternateIconName ?? "Default"
        }
    }
    
    private func setAppIcon(_ iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { 
            print("Device does not support alternate icons")
            return 
        }
        
        print("Setting app icon to: \(iconName ?? "Default")")
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Failed to set app icon to '\(iconName ?? "Default")': \(error.localizedDescription)")
            } else {
                print("Successfully set app icon to: \(iconName ?? "Default")")
            }
        }
    }
}

// MARK: - App Icon Info
struct AppIconInfo {
    let name: String
    let displayName: String
    let imageName: String
    let isDefault: Bool
}

// MARK: - App Icon Cell
struct AppIconCell: View {
    let iconInfo: AppIconInfo
    let isSelected: Bool
    let action: () -> Void
    @State private var iconImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    if isLoading {
                        ProgressView()
                            .frame(width: 70, height: 70)
                            .scaleEffect(0.7)
                    } else if let image = iconImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange)
                            )
                    }
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.blue, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                
                Text(iconInfo.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadIconAsync()
        }
    }
    
    private func loadIconAsync() async {
        await Task.detached(priority: .userInitiated) {
            let image = IconCacheManager.shared.getIcon(named: iconInfo.imageName)
            await MainActor.run {
                self.iconImage = image
                self.isLoading = false
            }
        }.value
    }
}

// MARK: - Settings Row View
struct SettingsRowView<Destination: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let destination: Destination?
    
    init(title: String, icon: String, iconColor: Color, destination: Destination? = nil) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.destination = destination
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

// Convenience initializer for SettingsRowView without destination
extension SettingsRowView where Destination == EmptyView {
    init(title: String, icon: String, iconColor: Color) {
        self.init(title: title, icon: icon, iconColor: iconColor, destination: EmptyView())
    }
}