import Foundation
import SwiftUI

// MARK: - User Mood Model

/// 用户心情模型
struct UserMood: Codable, Identifiable, Equatable {
    let id: UUID
    let mood: MoodType
    let intensity: MoodIntensity
    let timestamp: Date
    
    init(mood: MoodType, intensity: MoodIntensity = .normal, timestamp: Date = Date()) {
        self.id = UUID()
        self.mood = mood
        self.intensity = intensity
        self.timestamp = timestamp
    }
}

/// 心情类型
enum MoodType: String, CaseIterable, Codable {
    case happy = "happy"
    case excited = "excited"
    case calm = "calm"
    case tired = "tired"
    case stressed = "stressed"
    case sad = "sad"
    case anxious = "anxious"
    case energetic = "energetic"
    case romantic = "romantic"
    case nostalgic = "nostalgic"
    
    var localizedName: String {
        switch self {
        case .happy: return "mood.happy".localized
        case .excited: return "mood.excited".localized
        case .calm: return "mood.calm".localized
        case .tired: return "mood.tired".localized
        case .stressed: return "mood.stressed".localized
        case .sad: return "mood.sad".localized
        case .anxious: return "mood.anxious".localized
        case .energetic: return "mood.energetic".localized
        case .romantic: return "mood.romantic".localized
        case .nostalgic: return "mood.nostalgic".localized
        }
    }
    
    var iconName: String {
        switch self {
        case .happy: return "face.smiling"
        case .excited: return "star.fill"
        case .calm: return "leaf.fill"
        case .tired: return "moon.fill"
        case .stressed: return "bolt.fill"
        case .sad: return "cloud.rain.fill"
        case .anxious: return "exclamationmark.triangle.fill"
        case .energetic: return "flame.fill"
        case .romantic: return "heart.fill"
        case .nostalgic: return "clock.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .happy: return .yellow
        case .excited: return .orange
        case .calm: return .green
        case .tired: return .indigo
        case .stressed: return .red
        case .sad: return .blue
        case .anxious: return .purple
        case .energetic: return .pink
        case .romantic: return .red
        case .nostalgic: return .brown
        }
    }
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .excited: return "🤩"
        case .calm: return "😌"
        case .tired: return "😴"
        case .stressed: return "😰"
        case .sad: return "😢"
        case .anxious: return "😟"
        case .energetic: return "⚡"
        case .romantic: return "💕"
        case .nostalgic: return "🥺"
        }
    }
    
    /// 获取适合的食物建议类型
    var suggestedFoodTypes: [String] {
        switch self {
        case .happy, .excited:
            return ["celebration", "colorful", "fresh"]
        case .calm:
            return ["light", "healthy", "warm"]
        case .tired:
            return ["comfort", "energizing", "warm"]
        case .stressed:
            return ["comfort", "simple", "soothing"]
        case .sad:
            return ["comfort", "warm", "sweet"]
        case .anxious:
            return ["simple", "familiar", "soothing"]
        case .energetic:
            return ["fresh", "protein", "vibrant"]
        case .romantic:
            return ["elegant", "special", "wine-pairing"]
        case .nostalgic:
            return ["traditional", "homestyle", "familiar"]
        }
    }
}

/// 心情强度
enum MoodIntensity: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    
    var localizedName: String {
        switch self {
        case .low: return "mood.intensity.low".localized
        case .normal: return "mood.intensity.normal".localized
        case .high: return "mood.intensity.high".localized
        }
    }
    
    var multiplier: Double {
        switch self {
        case .low: return 0.5
        case .normal: return 1.0
        case .high: return 1.5
        }
    }
}

// MARK: - Mood Extensions

extension UserMood {
    /// 获取心情描述
    var description: String {
        let baseDesc = mood.localizedName
        switch intensity {
        case .low:
            return String(format: "mood.description.low".localized, baseDesc)
        case .normal:
            return baseDesc
        case .high:
            return String(format: "mood.description.high".localized, baseDesc)
        }
    }
    
    /// 是否是积极心情
    var isPositive: Bool {
        switch mood {
        case .happy, .excited, .calm, .energetic, .romantic:
            return true
        case .tired, .stressed, .sad, .anxious, .nostalgic:
            return false
        }
    }
    
    /// 是否需要安慰性食物
    var needsComfortFood: Bool {
        switch mood {
        case .stressed, .sad, .anxious, .tired:
            return true
        default:
            return false
        }
    }
    
    /// 是否适合轻食
    var prefersLightFood: Bool {
        switch mood {
        case .calm, .happy, .energetic:
            return true
        default:
            return false
        }
    }
}

// MARK: - Mock Data

extension UserMood {
    static let mockMoods: [UserMood] = [
        UserMood(mood: .happy, intensity: .normal),
        UserMood(mood: .tired, intensity: .high),
        UserMood(mood: .excited, intensity: .normal),
        UserMood(mood: .calm, intensity: .low),
        UserMood(mood: .stressed, intensity: .high)
    ]
}