import SwiftUI

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            // Action can be defined later if needed
        }) {
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: ResponsiveDesign.IconSize.large, height: ResponsiveDesign.IconSize.large)
                        .glassedEffect(in: Circle(), interactive: false)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryTextGradient)
                    
                    Text(title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryTextColor)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .buttonStyle(InteractiveCardStyle(color: color))
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var primaryTextGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark 
                ? [.white, .white.opacity(0.9)] 
                : [Color.primary, Color.primary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            StatsCard(
                title: "Total Items",
                value: "24",
                icon: "archivebox.fill",
                color: .blue
            )
            
            StatsCard(
                title: "Expiring Soon",
                value: "3",
                icon: "clock.fill",
                color: .orange
            )
        }
        .padding()
    }
}