import SwiftUI

struct UnitGuidanceView: View {
    let foodItem: FoodItem
    let onUnitSelected: (String) -> Void
    
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            if isExpanded {
                unitSelectionGrid
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(containerBackground)
        .overlay(containerBorder)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text("unit.guidance.message".localized)
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? .orange.opacity(0.9) : .orange)
            
            Button(action: toggleExpansion) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var unitSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(foodItem.suggestedUnits, id: \.self) { unit in
                UnitSelectionButton(
                    unit: unit,
                    colorScheme: colorScheme,
                    onTap: { selectUnit(unit) }
                )
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .opacity
        ))
    }
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.regularMaterial)
            .overlay(glassOverlay)
    }
    
    private var glassOverlay: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            } else {
                // iOS 18-25 兼容效果：轻微阴影
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .shadow(color: .orange.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
    }
    
    private var containerBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(.orange.opacity(0.3), lineWidth: 1)
    }
    
    // MARK: - Actions
    
    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
    }
    
    private func selectUnit(_ unit: String) {
        onUnitSelected(unit)
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
    }
}

private struct UnitSelectionButton: View {
    let unit: String
    let colorScheme: ColorScheme
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(unit)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(buttonBackground)
                .foregroundColor(textColor)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.ultraThinMaterial)
            .overlay(buttonGlassOverlay)
    }
    
    private var buttonGlassOverlay: some View {
        Group {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            } else {
                // iOS 18-25 兼容效果：渐变边框
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .primary
    }
}

#Preview {
    VStack {
        UnitGuidanceView(
            foodItem: FoodItem(name: "牛奶", quantity: 2, unit: "个")
        ) { unit in
            print("Selected unit: \(unit)")
        }
        
        UnitGuidanceView(
            foodItem: FoodItem(name: "牛肉", quantity: 1, unit: "个")
        ) { unit in
            print("Selected unit: \(unit)")
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}