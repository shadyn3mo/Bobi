import SwiftUI

struct DynamicSearchButton: View {
    @Binding var searchText: String
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            if isExpanded {
                // 展开状态：完整搜索栏
                HStack(spacing: ResponsiveDesign.Spacing.small) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(iconColor)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("fridge.search.placeholder".localized, text: $searchText)
                        .foregroundColor(textColor)
                        .font(.system(size: 16))
                        .focused($isTextFieldFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(iconColor)
                                .font(.system(size: 16))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Button(action: collapseSearch) {
                        Text("common.cancel".localized)
                            .foregroundColor(secondaryTextColor)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.vertical, ResponsiveDesign.Spacing.small)
            } else {
                // 收缩状态：搜索按钮
                Button(action: expandSearch) {
                    HStack(spacing: ResponsiveDesign.Spacing.small * 0.67) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(iconColor)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("fridge.search.title".localized)
                            .foregroundColor(secondaryTextColor)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    .padding(.vertical, ResponsiveDesign.Spacing.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: isExpanded ? .infinity : nil)
        .frame(minWidth: isExpanded ? nil : ResponsiveDesign.ButtonSize.extraLarge * 0.67)
        .glassedBackground(shape: Capsule(), interactive: true)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
        .onChange(of: isTextFieldFocused) { _, focused in
            if !focused && searchText.isEmpty {
                collapseSearch()
            }
        }
    }
    
    private func expandSearch() {
        isExpanded = true
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            isTextFieldFocused = true
        }
    }
    
    private func collapseSearch() {
        isTextFieldFocused = false
        searchText = ""
        isExpanded = false
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? .white.opacity(0.8) : Color.secondary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .secondary
    }
    
    private var borderColor: Color {
        let opacity = isExpanded ? 0.2 : 0.1
        return colorScheme == .dark ? Color.white.opacity(opacity) : Color.black.opacity(opacity)
    }
}

#Preview {
    @Previewable @State var searchText = ""
    @Previewable @State var isExpanded = false
    
    return ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 30) {
            // 正常状态
            DynamicSearchButton(searchText: $searchText, isExpanded: $isExpanded)
            
            // 手动展开状态演示
            DynamicSearchButton(searchText: .constant("示例搜索"), isExpanded: .constant(true))
        }
        .padding()
    }
}