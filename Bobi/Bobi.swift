import SwiftUI
import SwiftData
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        setupNotificationCategories()
        
        return true
    }
    
    private func setupNotificationCategories() {
        let expirationCategory = UNNotificationCategory(
            identifier: "EXPIRATION_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // 移除补货提醒类别
        
        let shoppingCategory = UNNotificationCategory(
            identifier: "SHOPPING_LIST_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            expirationCategory,
            shoppingCategory
        ])
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        Task { @MainActor in
            if let notificationType = userInfo["type"] as? String {
                switch notificationType {
                case "expiration":
                    // 处理过期提醒点击
                    print("User clicked expiration reminder")
                case "shopping_list":
                    // 处理采购单提醒点击
                    print("User clicked shopping list reminder")
                default:
                    break
                }
            }
        }
        
        completionHandler()
    }
}

@main
struct FridgeMindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    private let themeManager = ThemeManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            FoodGroup.self,
            NutritionInfo.self,
            FamilyProfile.self,
            ShoppingListItem.self,
            FoodHistoryRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        // 检查是否需要清除旧数据（由于模式更改）
        if needsDatabaseReset() {
            print("Detected schema changes, resetting database...")
            Self.deleteCorruptedDatabase()
        }
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // 执行数据迁移检查
            Task { @MainActor in
                let context = container.mainContext
                DataMigrationService.shared.migrateStorageLocationIfNeeded(in: context)
            }
            
            // 创建版本标记文件
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let versionFile = documentsPath.appendingPathComponent("schema_version.txt")
            let currentVersion = "1.0_custom_allergies"
            try? currentVersion.write(to: versionFile, atomically: true, encoding: .utf8)
            
            return container
        } catch {
            print("Failed to create ModelContainer: \(error)")
            
            // 如果是数据库损坏或模式冲突，尝试删除旧数据库文件
            if error.localizedDescription.contains("migration") || 
               error.localizedDescription.contains("schema") ||
               error.localizedDescription.contains("cast") {
                print("Detected schema migration issue. Attempting to reset database...")
                
                // 删除数据库文件
                Self.deleteCorruptedDatabase()
                
                // 重新尝试创建容器
                do {
                    return try ModelContainer(for: schema, configurations: [modelConfiguration])
                } catch {
                    print("Failed to create ModelContainer after reset: \(error)")
                    // 最后的备用方案：内存数据库
                    let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    do {
                        return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                    } catch {
                        fatalError("Could not create fallback ModelContainer: \(error)")
                    }
                }
            } else {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.selectedTheme.colorScheme)
                .onAppear {
                    Task { @MainActor in
                        NotificationManager.shared.setModelContext(sharedModelContainer.mainContext)
                        
                        // 初始化HomeStatusService并设置模型上下文
                        HomeStatusService.shared.setModelContext(sharedModelContainer.mainContext)
                        
                        // 位置权限由 HomeStatusService 统一管理，避免重复请求
                        
                        // 执行历史记录自动清理
                        await HistoryRecordService.shared.performAutoCleanup(in: sharedModelContainer.mainContext)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private static func needsDatabaseReset() -> Bool {
        // 检查是否存在版本标记文件
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let versionFile = documentsPath.appendingPathComponent("schema_version.txt")
        
        let currentVersion = "1.0_custom_allergies"
        
        if FileManager.default.fileExists(atPath: versionFile.path) {
            do {
                let savedVersion = try String(contentsOf: versionFile, encoding: .utf8)
                if savedVersion.trimmingCharacters(in: .whitespacesAndNewlines) == currentVersion {
                    return false // 版本匹配，不需要重置
                } else {
                    print("Schema version mismatch: saved=\(savedVersion), current=\(currentVersion)")
                    return true // 版本不匹配，需要重置
                }
            } catch {
                print("Failed to read schema version file: \(error)")
                return true // 读取失败，保险起见重置
            }
        } else {
            // 版本文件不存在，可能是第一次运行或旧版本
            return true
        }
    }
    
    private static func deleteCorruptedDatabase() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            for url in contents {
                if url.pathExtension == "sqlite" || 
                   url.pathExtension == "sqlite-wal" || 
                   url.pathExtension == "sqlite-shm" ||
                   url.lastPathComponent.contains("default.store") {
                    try fileManager.removeItem(at: url)
                    print("Deleted database file: \(url.lastPathComponent)")
                }
            }
            
            // 创建新的版本标记文件
            let versionFile = documentsPath.appendingPathComponent("schema_version.txt")
            let currentVersion = "1.0_custom_allergies"
            try currentVersion.write(to: versionFile, atomically: true, encoding: .utf8)
            print("Created new schema version file")
            
        } catch {
            print("Failed to delete corrupted database files: \(error)")
        }
    }
}
