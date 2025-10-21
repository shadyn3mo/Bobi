import Foundation
import UserNotifications
import SwiftUI
import SwiftData

enum ReminderFrequency: String, CaseIterable {
    case realtime = "realtime"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var localizedDescription: String {
        switch self {
        case .realtime:
            return "notification.frequency.realtime".localized
        case .hourly:
            return "notification.frequency.hourly".localized
        case .daily:
            return "notification.frequency.daily".localized
        case .weekly:
            return "notification.frequency.weekly".localized
        case .monthly:
            return "notification.frequency.monthly".localized
        }
    }
}

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private var modelContext: ModelContext?
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshTime: Date = Date.distantPast
    
    // 库存提醒防抖动机制
    private var stockReminderTask: Task<Void, Never>?
    private var lastStockLevels: [String: Int] = [:]
    private var lastStockReminderTime: [String: Date] = [:]
    private let stockReminderCooldown: TimeInterval = 300 // 5分钟冷却时间
    
    // 标记是否是设置变更触发的更新
    private var isSettingsUpdate = false
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    @Published var expirationRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(expirationRemindersEnabled, forKey: "expirationRemindersEnabled")
            updateNotificationScheduleFromSettings()
        }
    }
    
    // 移除补货提醒功能，现在通过采购单管理
    // @Published var restockRemindersEnabled: Bool
    
    @Published var shoppingListRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(shoppingListRemindersEnabled, forKey: "shoppingListRemindersEnabled")
            updateNotificationScheduleFromSettings()
        }
    }
    
    @Published var reminderFrequency: ReminderFrequency {
        didSet {
            UserDefaults.standard.set(reminderFrequency.rawValue, forKey: "reminderFrequency")
            updateNotificationScheduleFromSettings()
        }
    }
    
    @Published var preferredReminderTime: Date {
        didSet {
            UserDefaults.standard.set(preferredReminderTime, forKey: "preferredReminderTime")
            updateNotificationScheduleFromSettings()
        }
    }
    
    @Published var preferredWeekday: Int {
        didSet {
            UserDefaults.standard.set(preferredWeekday, forKey: "preferredWeekday")
            updateNotificationScheduleFromSettings()
        }
    }
    
    @Published var preferredMonthDay: Int {
        didSet {
            UserDefaults.standard.set(preferredMonthDay, forKey: "preferredMonthDay")
            updateNotificationScheduleFromSettings()
        }
    }
    
    
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        expirationRemindersEnabled = UserDefaults.standard.bool(forKey: "expirationRemindersEnabled")
        // restockRemindersEnabled 已移除
        shoppingListRemindersEnabled = UserDefaults.standard.bool(forKey: "shoppingListRemindersEnabled")
        
        let frequencyString = UserDefaults.standard.string(forKey: "reminderFrequency") ?? ReminderFrequency.daily.rawValue
        reminderFrequency = ReminderFrequency(rawValue: frequencyString) ?? .daily
        
        if let savedTime = UserDefaults.standard.object(forKey: "preferredReminderTime") as? Date {
            preferredReminderTime = savedTime
        } else {
            var components = DateComponents()
            components.hour = 9
            components.minute = 0
            preferredReminderTime = Calendar.current.date(from: components) ?? Date()
        }
        
        preferredWeekday = UserDefaults.standard.object(forKey: "preferredWeekday") as? Int ?? 2 // Monday
        preferredMonthDay = UserDefaults.standard.object(forKey: "preferredMonthDay") as? Int ?? 1
        
        
        checkNotificationPermission()
    }
    
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            checkNotificationPermission()
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    // 从设置变更触发的更新，不会立即发送通知
    private func updateNotificationScheduleFromSettings() {
        isSettingsUpdate = true
        // 设置变更时需要清除所有通知并重新安排
        Task {
            // 清除所有现有通知
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            // 重新安排通知
            updateNotificationSchedule()
        }
        isSettingsUpdate = false
    }
    
    private func updateNotificationSchedule() {
        Task {
            // 获取现有的通知请求
            let existingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            
            // 保存非实时通知的标识符（这些是需要保留的定时通知）
            var scheduledNotificationIds = Set<String>()
            for request in existingRequests {
                if request.trigger is UNCalendarNotificationTrigger {
                    // 这是一个日历触发器（每小时/每天/每周/每月），需要保留
                    scheduledNotificationIds.insert(request.identifier)
                }
            }
            
            // 只移除不在保留列表中的通知
            var idsToRemove: [String] = []
            for request in existingRequests {
                if !scheduledNotificationIds.contains(request.identifier) {
                    idsToRemove.append(request.identifier)
                }
            }
            
            if !idsToRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
            
            // 清除应用图标上的角标
            if #available(iOS 16.0, *) {
                try? await UNUserNotificationCenter.current().setBadgeCount(0)
            } else {
                await MainActor.run {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }
            
            guard notificationPermissionStatus == .authorized else { return }
            
            if expirationRemindersEnabled {
                await scheduleExpirationReminders()
            }
            
            // 移除补货提醒，现在通过采购单管理
            
            if shoppingListRemindersEnabled {
                await scheduleShoppingListReminders()
            }
        }
    }
    
    private func scheduleExpirationReminders() async {
        guard let modelContext = modelContext else {
            print("ModelContext not available for scheduling expiration reminders")
            return
        }
        
        let fetchDescriptor = FetchDescriptor<FoodItem>()
        
        do {
            // 获取现有的通知请求标识符
            let existingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let existingIdentifiers = Set(existingRequests.map { $0.identifier })
            
            let foodItems = try modelContext.fetch(fetchDescriptor)
            let expiringItems = foodItems.filter { item in
                guard item.expirationDate != nil else { return false }
                let daysUntilExpiration = item.daysUntilExpiration ?? 0
                // 仅在今天或3天内过期时提醒
                return daysUntilExpiration <= 3 && daysUntilExpiration >= 0
            }
            
            for item in expiringItems {
                let identifier = "expiration_\(item.id.uuidString)"
                // 只有在通知不存在时才创建新的
                if !existingIdentifiers.contains(identifier) {
                    await scheduleExpirationReminder(for: item)
                }
            }
        } catch {
            print("Error fetching food items for expiration reminders: \(error)")
        }
    }
    
    // 移除补货提醒功能
    // private func scheduleRestockReminders() async { ... }
    
    func scheduleShoppingListReminders() async {
        guard let modelContext = modelContext else {
            print("ModelContext not available for scheduling shopping list reminders")
            return
        }
        
        let shoppingFetchDescriptor = FetchDescriptor<ShoppingListItem>()
        let foodFetchDescriptor = FetchDescriptor<FoodItem>()
        
        do {
            // 获取现有的通知请求标识符
            let existingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let existingIdentifiers = Set(existingRequests.map { $0.identifier })
            
            let shoppingItems = try modelContext.fetch(shoppingFetchDescriptor)
            let foodItems = try modelContext.fetch(foodFetchDescriptor)
            
            // 找出需要补货的具体项目
            var shortageItems: [ShoppingListItem] = []
            
            for item in shoppingItems {
                let currentStock = getCurrentStock(for: item, in: foodItems)
                let previousStock = lastStockLevels[item.name] ?? Int.max
                
                // 检查是否需要提醒
                if currentStock < item.minQuantity && item.alertEnabled {
                    // 检查是否刚从充足变为不足
                    let justBecameInsufficient = previousStock >= item.minQuantity && currentStock < item.minQuantity
                    
                    // 检查冷却时间
                    let lastReminderTime = lastStockReminderTime[item.name] ?? Date.distantPast
                    let timeSinceLastReminder = Date().timeIntervalSince(lastReminderTime)
                    let cooldownPassed = timeSinceLastReminder >= stockReminderCooldown
                    
                    // 对于非实时频率，总是添加到提醒列表
                    // 对于实时频率，只有在刚变为不足或冷却时间已过时才添加
                    if reminderFrequency != .realtime || justBecameInsufficient || cooldownPassed {
                        shortageItems.append(item)
                        if reminderFrequency == .realtime {
                            lastStockReminderTime[item.name] = Date()
                        }
                    }
                }
                
                // 更新库存记录
                lastStockLevels[item.name] = currentStock
            }
            
            if !shortageItems.isEmpty {
                // 只有在通知不存在时才创建新的
                let shoppingIdentifier = "shopping_list_reminder_\(reminderFrequency.rawValue)"
                if !existingIdentifiers.contains(shoppingIdentifier) {
                    await scheduleShoppingListReminder(shortageItems: shortageItems)
                }
            }
        } catch {
            print("Error fetching shopping list items for reminders: \(error)")
        }
    }
    
    // 专门用于特定食材的库存提醒检查
    func scheduleShoppingListReminders(for specificFoodItems: [FoodItem]) async {
        guard let modelContext = modelContext else {
            print("ModelContext not available for scheduling shopping list reminders")
            return
        }
        
        let shoppingFetchDescriptor = FetchDescriptor<ShoppingListItem>()
        
        do {
            // 获取现有的通知请求标识符
            let existingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let existingIdentifiers = Set(existingRequests.map { $0.identifier })
            
            let shoppingItems = try modelContext.fetch(shoppingFetchDescriptor)
            
            // 找出需要补货的具体项目
            var shortageItems: [ShoppingListItem] = []
            
            for item in shoppingItems {
                let currentStock = getCurrentStock(for: item, in: specificFoodItems)
                let previousStock = lastStockLevels[item.name] ?? Int.max
                
                // 检查是否需要提醒
                if currentStock < item.minQuantity && item.alertEnabled {
                    // 检查是否刚从充足变为不足
                    let justBecameInsufficient = previousStock >= item.minQuantity && currentStock < item.minQuantity
                    
                    // 检查冷却时间
                    let lastReminderTime = lastStockReminderTime[item.name] ?? Date.distantPast
                    let timeSinceLastReminder = Date().timeIntervalSince(lastReminderTime)
                    let cooldownPassed = timeSinceLastReminder >= stockReminderCooldown
                    
                    // 对于非实时频率，总是添加到提醒列表
                    // 对于实时频率，只有在刚变为不足或冷却时间已过时才添加
                    if reminderFrequency != .realtime || justBecameInsufficient || cooldownPassed {
                        shortageItems.append(item)
                        if reminderFrequency == .realtime {
                            lastStockReminderTime[item.name] = Date()
                        }
                    }
                }
                
                // 更新库存记录
                lastStockLevels[item.name] = currentStock
            }
            
            if !shortageItems.isEmpty {
                // 只有在通知不存在时才创建新的
                let shoppingIdentifier = "shopping_list_reminder_\(reminderFrequency.rawValue)"
                if !existingIdentifiers.contains(shoppingIdentifier) {
                    await scheduleShoppingListReminder(shortageItems: shortageItems)
                }
            }
        } catch {
            print("Error fetching shopping list items for reminders: \(error)")
        }
    }
    
    private func getCurrentStock(for item: ShoppingListItem, in foodItems: [FoodItem]) -> Int {
        let groupingService = FoodGroupingService.shared
        
        let matchingItems = foodItems.filter { foodItem in
            // 使用FoodGroupingService进行智能匹配
            return groupingService.shouldGroup(item.name, foodItem.name)
        }
        
        let totalStock = matchingItems.reduce(0) { total, foodItem in
            return total + foodItem.quantity
        }
        
        print("📊 [NotificationManager] 检查 '\(item.name)' 的库存:")
        print("   - 匹配食材: \(matchingItems.map { "\($0.name)(\($0.quantity))" }.joined(separator: ", "))")
        print("   - 总库存: \(totalStock), 最小库存: \(item.minQuantity)")
        print("   - 库存充足: \(totalStock >= item.minQuantity)")
        
        return totalStock
    }
    
    func getEffectiveReminderDescription() -> String {
        switch reminderFrequency {
        case .realtime:
            return "notification.description.realtime".localized
        case .hourly:
            return "notification.description.hourly".localized
        case .daily:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: preferredReminderTime)
            return String(format: "notification.description.daily".localized, timeString)
        case .weekly:
            let formatter = DateFormatter()
            formatter.weekdaySymbols = Calendar.current.weekdaySymbols
            let dayString = formatter.weekdaySymbols[preferredWeekday - 1]
            formatter.timeStyle = .short
            let timeString = formatter.string(from: preferredReminderTime)
            return String(format: "notification.description.weekly".localized, dayString, timeString)
        case .monthly:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: preferredReminderTime)
            let dayString = getMonthDayDescription(day: preferredMonthDay)
            return String(format: "notification.description.monthly".localized, dayString, timeString)
        }
    }
    
    private func getMonthDayDescription(day: Int) -> String {
        if day > 28 {
            return String(format: "notification.monthday.endofmonth".localized, day)
        } else {
            return String(day)
        }
    }
    
    func getWeekdayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.weekdaySymbols = Calendar.current.weekdaySymbols
        return formatter.weekdaySymbols[weekday - 1]
    }
    
    // MARK: - Individual Reminder Scheduling
    
    private func scheduleExpirationReminder(for item: FoodItem) async {
        guard let expirationDate = item.expirationDate,
              let daysUntilExpiration = item.daysUntilExpiration else { return }
        
        // 如果是设置变更且是实时模式，不创建通知
        if isSettingsUpdate && reminderFrequency == .realtime {
            return
        }
        
        let identifier = "expiration_\(item.id.uuidString)"
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = "EXPIRATION_REMINDER"
        content.userInfo = ["foodItemId": item.id.uuidString, "type": "expiration"]
        
        // 清理食材名称，移除测试前缀和表情符号
        let cleanItemName = item.name
            .replacingOccurrences(of: "测试", with: "")
            .replacingOccurrences(of: "🥛", with: "")
            .replacingOccurrences(of: "🍞", with: "")
            .replacingOccurrences(of: "🍎", with: "")
            .replacingOccurrences(of: "🥚", with: "")
            .replacingOccurrences(of: "🥕", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        // 设置通知内容
        if daysUntilExpiration == 0 {
            content.title = "notification.expiration.today.title".localized
            content.body = String(format: "notification.expiration.today.body".localized, cleanItemName)
        } else if daysUntilExpiration == 1 {
            content.title = "notification.expiration.tomorrow.title".localized
            content.body = String(format: "notification.expiration.tomorrow.body".localized, cleanItemName)
        } else {
            content.title = "notification.expiration.soon.title".localized
            content.body = String(format: "notification.expiration.soon.body".localized, cleanItemName, daysUntilExpiration)
        }
        
        let trigger = createTrigger(for: reminderFrequency, targetDate: expirationDate)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            // print("Successfully scheduled expiration reminder for: \(cleanItemName)")
        } catch {
            print("Error scheduling expiration reminder: \(error)")
        }
    }
    
    // 移除补货提醒功能
    // private func scheduleRestockReminder(for item: FoodItem) async { ... }
    
    private func scheduleShoppingListReminder(shortageItems: [ShoppingListItem]) async {
        // 如果是设置变更且是实时模式，不创建通知
        if isSettingsUpdate && reminderFrequency == .realtime {
            return
        }
        
        // 为不同频率创建唯一标识符
        let identifier = "shopping_list_reminder_\(reminderFrequency.rawValue)"
        
        let content = UNMutableNotificationContent()
        content.title = "notification.shopping.title".localized
        
        // 创建具体的食材清单
        if shortageItems.count == 1 {
            // 单个食材时显示具体名称
            let itemName = shortageItems[0].name.replacingOccurrences(of: "测试", with: "").trimmingCharacters(in: .whitespaces)
            content.body = String(format: "notification.shopping.single.body".localized, itemName)
        } else if shortageItems.count <= 3 {
            // 2-3个食材时列出所有名称
            let itemNames = shortageItems.map { 
                $0.name.replacingOccurrences(of: "测试", with: "").trimmingCharacters(in: .whitespaces)
            }.joined(separator: "、")
            content.body = String(format: "notification.shopping.multiple.body".localized, itemNames)
        } else {
            // 超过3个时显示前2个+数量
            let firstTwo = shortageItems.prefix(2).map { 
                $0.name.replacingOccurrences(of: "测试", with: "").trimmingCharacters(in: .whitespaces)
            }.joined(separator: "、")
            let remainingCount = shortageItems.count - 2
            content.body = String(format: "notification.shopping.many.body".localized, firstTwo, remainingCount)
        }
        
        content.sound = .default
        content.categoryIdentifier = "SHOPPING_LIST_REMINDER"
        content.userInfo = [
            "type": "shopping_list", 
            "itemCount": shortageItems.count,
            "itemNames": shortageItems.map { $0.name }
        ]
        
        let trigger = createTrigger(for: reminderFrequency)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            // print("Successfully scheduled shopping list reminder for \(shortageItems.count) items")
        } catch {
            print("Error scheduling shopping list reminder: \(error)")
        }
    }
    
    private func createTrigger(for frequency: ReminderFrequency, targetDate: Date? = nil) -> UNNotificationTrigger {
        switch frequency {
        case .realtime:
            return UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
        case .hourly:
            var components = DateComponents()
            components.minute = 0
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
        case .daily:
            let time = Calendar.current.dateComponents([.hour, .minute], from: preferredReminderTime)
            var components = DateComponents()
            components.hour = time.hour
            components.minute = time.minute
            
            if let targetDate = targetDate {
                let targetComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
                components.year = targetComponents.year
                components.month = targetComponents.month
                components.day = targetComponents.day
            }
            
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: targetDate == nil)
            
        case .weekly:
            let time = Calendar.current.dateComponents([.hour, .minute], from: preferredReminderTime)
            var components = DateComponents()
            components.weekday = preferredWeekday
            components.hour = time.hour
            components.minute = time.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
        case .monthly:
            let time = Calendar.current.dateComponents([.hour, .minute], from: preferredReminderTime)
            var components = DateComponents()
            components.day = preferredMonthDay
            components.hour = time.hour
            components.minute = time.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }
    
    
    // MARK: - Public Methods
    
    func refreshNotifications() {
        // 防抖处理：如果上次刷新时间距离现在不足30秒，则跳过
        let now = Date()
        let timeSinceLastRefresh = now.timeIntervalSince(lastRefreshTime)
        
        if timeSinceLastRefresh < 30 {
            return
        }
        
        // 取消之前的刷新任务
        refreshTask?.cancel()
        
        // 创建新的刷新任务
        refreshTask = Task {
            // 延迟1秒执行，进一步防抖
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            lastRefreshTime = now
            updateNotificationSchedule()
        }
    }
    
    // 专门用于库存变化的提醒触发
    func triggerStockChangeReminder() {
        // 取消之前的库存提醒任务
        stockReminderTask?.cancel()
        
        // 创建新的库存提醒任务
        stockReminderTask = Task {
            // 延迟2秒执行，防止快速连续的库存变化
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            // 只在实时提醒模式下触发
            if reminderFrequency == .realtime && shoppingListRemindersEnabled {
                await scheduleShoppingListReminders()
            }
        }
    }
    
    // 专门用于特定食材的库存变化提醒触发
    func triggerStockChangeReminder(for specificFoodItems: [FoodItem]) {
        // 取消之前的库存提醒任务
        stockReminderTask?.cancel()
        
        // 创建新的库存提醒任务
        stockReminderTask = Task {
            // 延迟2秒执行，防止快速连续的库存变化
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            guard !Task.isCancelled else { return }
            
            // 只在实时提醒模式下触发
            if reminderFrequency == .realtime && shoppingListRemindersEnabled {
                await scheduleShoppingListReminders(for: specificFoodItems)
            }
        }
    }
    
    // 专门为已消耗食材的定向库存提醒
    func scheduleTargetedShoppingReminder(for items: [ShoppingListItem]) async {
        guard shoppingListRemindersEnabled else {
            print("📵 [NotificationManager] 购物提醒已禁用，跳过定向提醒")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "notification.shopping.targeted.title".localized
        
        if items.count == 1 {
            let item = items.first!
            content.body = String(format: "notification.shopping.targeted.single".localized, item.name)
        } else {
            let itemNames = items.prefix(3).map { $0.name }.joined(separator: ", ")
            if items.count > 3 {
                content.body = String(format: "notification.shopping.targeted.multiple.overflow".localized, itemNames, items.count - 3)
            } else {
                content.body = String(format: "notification.shopping.targeted.multiple".localized, itemNames)
            }
        }
        
        content.sound = .default
        content.categoryIdentifier = "SHOPPING_REMINDER"
        
        // 使用唯一标识符避免重复通知
        let identifier = "targeted_shopping_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 [NotificationManager] 已发送定向补货提醒: \(items.map { $0.name }.joined(separator: ", "))")
        } catch {
            print("❌ [NotificationManager] 发送定向补货提醒失败: \(error)")
        }
    }
    
    func clearBadgeNumber() {
        Task { @MainActor in
            if #available(iOS 16.0, *) {
                try? await UNUserNotificationCenter.current().setBadgeCount(0)
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
    
    func cancelNotification(for foodItemId: UUID) {
        let expirationId = "expiration_\(foodItemId.uuidString)"
        // 不再需要取消补货提醒
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [expirationId])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func getPendingNotificationCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
}