import SwiftUI

// MARK: - Modern Navigation Card
struct ModernNavigationCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let destination: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }

                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

// MARK: - Permission Status View
struct PermissionStatusView: View {
    let title: String
    let description: String
    let statusText: String
    let statusColor: Color
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusColor)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            Button(action: action) {
                Text("permissions.manage".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

// MARK: - AI Status Header View
struct AIStatusHeaderView: View {
    let status: AIConnectionView.AIConnectionStatus
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                
                Circle()
                    .fill(status.color.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                
                Image(systemName: status.icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(status.color)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            
            Text(status.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(status.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(backgroundGradient)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [status.color.opacity(0.2), status.color.opacity(0.0)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
} 