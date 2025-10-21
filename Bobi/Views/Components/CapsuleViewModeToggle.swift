import SwiftUI

struct CapsuleViewModeToggle: View {
    @Binding var selectedMode: InventoryListView.ViewMode
    @Environment(\.colorScheme) var colorScheme
    @State private var themeManager = ThemeManager.shared
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(InventoryListView.ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) {
                        selectedMode = mode
                    }
                }) {
                    HStack(spacing: ResponsiveDesign.Spacing.small * 0.67) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text(mode.localizedName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(selectedMode == mode ? .primary : secondaryTextColor)
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.vertical, ResponsiveDesign.Spacing.small * 0.83)
                    .background {
                        if selectedMode == mode {
                            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                                .glassedEffect(in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium), interactive: true)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(capsuleBackgroundColor)
                .overlay(
                    Capsule()
                        .stroke(outerBorderColor, lineWidth: 1)
                )
        }
        .glassedEffect(in: Capsule(), interactive: false)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .secondary
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1)
    }
    
    private var outerBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    private var capsuleBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5)
    }
}

extension InventoryListView.ViewMode {
    var icon: String {
        switch self {
        case .byCategory:
            return "square.grid.2x2"
        case .byStorage:
            return "shippingbox"
        }
    }
}

#Preview {
    @Previewable @State var mode: InventoryListView.ViewMode = .byCategory
    
    return ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        CapsuleViewModeToggle(selectedMode: $mode)
            .padding()
    }
}