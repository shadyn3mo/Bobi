import Foundation
import SwiftUI

@MainActor
class DailyUsageManager: ObservableObject {
    static let shared = DailyUsageManager()
    
    @Published var remainingUsage: Int = 0
    @Published var totalDailyLimit: Int = 10
    
    private let userDefaults = UserDefaults.standard
    private let usageKey = "daily_ai_usage"
    private let lastUsageDateKey = "last_usage_date"
    
    private init() {
        loadDailyUsage()
    }
    
    private func loadDailyUsage() {
        totalDailyLimit = EnvironmentLoader.shared.freeAIDailyLimit
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastUsageDate = userDefaults.object(forKey: lastUsageDateKey) as? Date ?? Date.distantPast
        let lastUsageDateStart = Calendar.current.startOfDay(for: lastUsageDate)
        
        if today == lastUsageDateStart {
            let usedCount = userDefaults.integer(forKey: usageKey)
            remainingUsage = max(0, totalDailyLimit - usedCount)
        } else {
            remainingUsage = totalDailyLimit
            userDefaults.set(0, forKey: usageKey)
            userDefaults.set(Date(), forKey: lastUsageDateKey)
        }
    }
    
    func canUseAI() -> Bool {
        return remainingUsage > 0
    }
    
    func incrementUsage() {
        guard canUseAI() else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastUsageDate = userDefaults.object(forKey: lastUsageDateKey) as? Date ?? Date.distantPast
        let lastUsageDateStart = Calendar.current.startOfDay(for: lastUsageDate)
        
        let currentUsage = userDefaults.integer(forKey: usageKey)
        
        if today != lastUsageDateStart {
            userDefaults.set(0, forKey: usageKey)
            userDefaults.set(Date(), forKey: lastUsageDateKey)
            userDefaults.set(1, forKey: usageKey)
            Task { @MainActor in
                remainingUsage = totalDailyLimit - 1
            }
        } else {
            userDefaults.set(currentUsage + 1, forKey: usageKey)
            Task { @MainActor in
                remainingUsage = max(0, totalDailyLimit - (currentUsage + 1))
            }
        }
    }
    
    func resetDailyUsage() {
        userDefaults.set(0, forKey: usageKey)
        userDefaults.set(Date(), forKey: lastUsageDateKey)
        remainingUsage = totalDailyLimit
    }
    
    var usagePercentage: Double {
        let used = totalDailyLimit - remainingUsage
        return Double(used) / Double(totalDailyLimit)
    }
    
    var timeUntilReset: String {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let timeInterval = tomorrow.timeIntervalSince(now)
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        return String(format: "%02d:%02d", hours, minutes)
    }
}