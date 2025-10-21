import SwiftUI

struct StatusRingView: View {
    let status: StatusType
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    enum StatusType {
        case ready
        case syncing
        case offline
        case error
        
        var color: Color {
            switch self {
            case .ready: return .green
            case .syncing: return .blue
            case .offline: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .ready: return "checkmark.circle.fill"
            case .syncing: return "arrow.2.circlepath"
            case .offline: return "wifi.slash"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: ResponsiveDesign.Spacing.small) {
            ZStack {
                // 外圈
                Circle()
                    .stroke(status.color.opacity(0.3), lineWidth: 2)
                    .frame(width: ResponsiveDesign.IconSize.small, height: ResponsiveDesign.IconSize.small)
                
                // 内圈和图标
                if status == .syncing {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(status.color, lineWidth: 2)
                        .frame(width: ResponsiveDesign.IconSize.small, height: ResponsiveDesign.IconSize.small)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                } else {
                    Circle()
                        .fill(status.color)
                        .frame(width: ResponsiveDesign.IconSize.small * 0.625, height: ResponsiveDesign.IconSize.small * 0.625)
                        .shadow(color: status.color.opacity(0.4), radius: 4, x: 0, y: 2)
                }
            }
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.small)
        .padding(.vertical, ResponsiveDesign.Spacing.small * 0.67)
        .glassedBackground(shape: Capsule(), interactive: false)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color.secondary
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
}

#Preview {
    VStack(spacing: 20) {
        StatusRingView(status: .ready, text: "就绪")
        StatusRingView(status: .syncing, text: "同步中")
        StatusRingView(status: .offline, text: "离线")
        StatusRingView(status: .error, text: "错误")
    }
    .padding()
    .background {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}