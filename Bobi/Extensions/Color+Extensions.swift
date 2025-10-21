import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func lighter(by percentage: CGFloat = 30.0) -> Color {
        return self.adjust(by: abs(percentage/100.0))
    }

    func darker(by percentage: CGFloat = 30.0) -> Color {
        return self.adjust(by: -abs(percentage/100.0))
    }

    private func adjust(by percentage: CGFloat) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color(UIColor(
                red: min(max(red + percentage, 0), 1),
                green: min(max(green + percentage, 0), 1),
                blue: min(max(blue + percentage, 0), 1),
                alpha: alpha
            ))
        }
        return self
    }
    
    static var badgeShowHideColor: Color {
        Color(.label)
    }
} 