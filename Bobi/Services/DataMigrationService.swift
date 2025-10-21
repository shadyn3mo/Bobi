import Foundation
import SwiftData

class DataMigrationService {
    static let shared = DataMigrationService()
    
    private init() {}
    
    func migrateStorageLocationIfNeeded(in modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<FoodItem>()
            let allItems = try modelContext.fetch(descriptor)
            
            print("[DataMigration] Checking \(allItems.count) items for storage location migration")
            
            var needsSave = false
            
            // 检查并修复缺失的存储位置
            for item in allItems {
                // 如果访问存储位置失败，设置推荐位置
                if item.storageLocation == nil {
                    print("[DataMigration] storageLocation is nil for '\(item.name)', setting recommended location")
                    let recommended = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: item.name, category: item.category)
                    item.storageLocation = recommended
                    needsSave = true
                }
            }
            
            if needsSave {
                try modelContext.save()
                print("[DataMigration] Successfully migrated \(allItems.count) items")
            } else {
                print("[DataMigration] No migration needed")
            }
            
        } catch {
            print("[DataMigration] Error during migration: \(error)")
            handleDataCorruption(in: modelContext)
        }
    }
    
    private func handleDataCorruption(in modelContext: ModelContext) {
        print("[DataMigration] Attempting to handle data corruption...")
        
        // 这里可以实现更复杂的数据恢复逻辑
        // 目前先记录错误，让应用的错误处理机制接管
        
        // 可选：尝试删除损坏的数据文件并重新开始
        // 但这需要用户确认，所以在这里只记录
    }
    
    private func shouldUpdateStorageLocation(item: FoodItem, recommended: StorageLocation) -> Bool {
        // 这里可以添加更复杂的逻辑来决定是否需要更新
        // 目前简单地返回 false，表示不自动修改现有数据
        return false
    }
}