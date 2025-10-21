import SwiftUI

// MARK: - Weather Theme Models

struct WeatherTheme {
    let primaryColors: [Color]           // 主要渐变色彩
    let secondaryColors: [Color]         // 次要渐变色彩
    let accentColor: Color              // 强调色
    let backgroundGradient: [Color]     // 背景渐变
    let decorativeCircle1: [Color]      // 装饰圆圈1
    let decorativeCircle2: [Color]      // 装饰圆圈2
    let cardBackground: Color           // 卡片背景
    let shadowColor: Color              // 阴影颜色
    let textPrimary: Color             // 主要文字颜色
    let textSecondary: Color           // 次要文字颜色
}

// MARK: - Weather Theme Manager

@MainActor
class WeatherThemeManager: ObservableObject {
    @Published var currentWeather: WeatherCondition = .sunny
    @Published var currentTheme: WeatherTheme
    
    init() {
        self.currentTheme = Self.themes[.sunny]!
    }
    
    func updateTheme(for weather: WeatherCondition) {
        withAnimation(.easeInOut(duration: 0.8)) {
            currentWeather = weather
            currentTheme = Self.themes[weather] ?? Self.themes[.sunny]!
        }
    }
    
    // MARK: - Predefined Themes
    static let themes: [WeatherCondition: WeatherTheme] = [
        .sunny: WeatherTheme(
            primaryColors: [.yellow, .orange],
            secondaryColors: [.orange, .red.opacity(0.8)],
            accentColor: .yellow,
            backgroundGradient: [
                Color.yellow.opacity(0.1),
                Color.orange.opacity(0.05),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.yellow.opacity(0.3), .orange.opacity(0.2)],
            decorativeCircle2: [.orange.opacity(0.25), .red.opacity(0.15)],
            cardBackground: Color.yellow.opacity(0.05),
            shadowColor: Color.yellow.opacity(0.2),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        ),
        
        .rainy: WeatherTheme(
            primaryColors: [.blue, .cyan],
            secondaryColors: [.cyan, .blue.opacity(0.8)],
            accentColor: .blue,
            backgroundGradient: [
                Color.blue.opacity(0.08),
                Color.cyan.opacity(0.04),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.blue.opacity(0.25), .cyan.opacity(0.15)],
            decorativeCircle2: [.cyan.opacity(0.2), .blue.opacity(0.1)],
            cardBackground: Color.blue.opacity(0.03),
            shadowColor: Color.blue.opacity(0.15),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        ),
        
        .cloudy: WeatherTheme(
            primaryColors: [.gray, .secondary],
            secondaryColors: [.secondary, .gray.opacity(0.8)],
            accentColor: .gray,
            backgroundGradient: [
                Color.gray.opacity(0.06),
                Color.secondary.opacity(0.03),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.gray.opacity(0.2), .secondary.opacity(0.12)],
            decorativeCircle2: [.secondary.opacity(0.15), .gray.opacity(0.08)],
            cardBackground: Color.gray.opacity(0.02),
            shadowColor: Color.gray.opacity(0.12),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        ),
        
        .cold: WeatherTheme(
            primaryColors: [.cyan, .blue],
            secondaryColors: [.blue, .indigo.opacity(0.8)],
            accentColor: .cyan,
            backgroundGradient: [
                Color.cyan.opacity(0.08),
                Color.blue.opacity(0.04),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.cyan.opacity(0.25), .blue.opacity(0.15)],
            decorativeCircle2: [.blue.opacity(0.2), .indigo.opacity(0.1)],
            cardBackground: Color.cyan.opacity(0.03),
            shadowColor: Color.cyan.opacity(0.15),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        ),
        
        .hot: WeatherTheme(
            primaryColors: [.red, .orange],
            secondaryColors: [.orange, .pink.opacity(0.8)],
            accentColor: .red,
            backgroundGradient: [
                Color.red.opacity(0.08),
                Color.orange.opacity(0.04),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.red.opacity(0.25), .orange.opacity(0.15)],
            decorativeCircle2: [.orange.opacity(0.2), .pink.opacity(0.1)],
            cardBackground: Color.red.opacity(0.03),
            shadowColor: Color.red.opacity(0.15),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        ),
        
        .windy: WeatherTheme(
            primaryColors: [.mint, .green],
            secondaryColors: [.green, .teal.opacity(0.8)],
            accentColor: .mint,
            backgroundGradient: [
                Color.mint.opacity(0.08),
                Color.green.opacity(0.04),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.mint.opacity(0.25), .green.opacity(0.15)],
            decorativeCircle2: [.green.opacity(0.2), .teal.opacity(0.1)],
            cardBackground: Color.mint.opacity(0.03),
            shadowColor: Color.mint.opacity(0.15),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        ),
        
        .snowy: WeatherTheme(
            primaryColors: [.gray, .blue.opacity(0.6)],
            secondaryColors: [.blue.opacity(0.5), .indigo.opacity(0.4)],
            accentColor: .gray,
            backgroundGradient: [
                Color.blue.opacity(0.08),
                Color.gray.opacity(0.06),
                Color(.systemBackground)
            ],
            decorativeCircle1: [.blue.opacity(0.2), .gray.opacity(0.15)],
            decorativeCircle2: [.gray.opacity(0.18), .indigo.opacity(0.1)],
            cardBackground: Color.blue.opacity(0.03),
            shadowColor: Color.blue.opacity(0.12),
            textPrimary: Color.primary,
            textSecondary: Color.secondary
        )
    ]
}

// MARK: - Convenience Extensions

extension WeatherTheme {
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: primaryColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var secondaryGradient: LinearGradient {
        LinearGradient(
            colors: secondaryColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var backgroundLinearGradient: LinearGradient {
        LinearGradient(
            colors: backgroundGradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var decorativeCircle1Gradient: LinearGradient {
        LinearGradient(
            colors: decorativeCircle1,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var decorativeCircle2Gradient: LinearGradient {
        LinearGradient(
            colors: decorativeCircle2,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}