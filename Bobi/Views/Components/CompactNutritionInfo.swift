import SwiftUI

struct CompactNutritionInfo: View {
    let calorieTarget: Int?
    let recommendedDishes: Int
    @Environment(\.colorScheme) var colorScheme
    @State private var showingBMRInfo = false
    
    var body: some View {
        VStack(spacing: 8) {
            // 卡路里和菜品数量 - 更大的布局
            HStack(spacing: 20) {
                nutritionItem(
                    icon: "flame.fill",
                    value: "\(calorieTarget ?? 0)",
                    unit: "kcal",
                    color: .orange,
                    showInfoButton: true
                )
                
                Divider()
                    .frame(height: 50)
                    .overlay(Color.secondary.opacity(0.3))
                
                nutritionItem(
                    icon: "list.bullet.rectangle.portrait.fill",
                    value: "\(recommendedDishes)",
                    unit: "dishes",
                    color: .blue,
                    showInfoButton: false
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 0.5)
                    )
            )
            
            // AI 提示
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("recipe.smart.generation.note".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.08))
            )
        }
        .alert("bmr.title".localized, isPresented: $showingBMRInfo) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text("bmr.calculation.info".localized)
        }
    }
    
    @ViewBuilder
    private func nutritionItem(icon: String, value: String, unit: String, color: Color, showInfoButton: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                    
                    Text(unit.localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                HStack(spacing: 4) {
                    Text(unit == "kcal" ? "recipe.daily.calories".localized : "recipe.recommended.dishes".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                    
                    if showInfoButton {
                        Button(action: {
                            showingBMRInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue.opacity(0.7))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color(.tertiarySystemBackground)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }
}