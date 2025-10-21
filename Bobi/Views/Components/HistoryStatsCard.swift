import SwiftUI

struct HistoryStatsCard: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("fridge.history.title".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.leading)
                
                Text("fridge.history.subtitle".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .padding(.vertical, ResponsiveDesign.Spacing.small)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .glassedBackground(shape: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium), interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : Color.secondary
    }
    
    private var borderColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.15) 
            : Color.black.opacity(0.1)
    }
}

#Preview {
    HStack(spacing: 12) {
        HistoryStatsCard()
    }
    .padding()
    .background(Color(.systemBackground))
}