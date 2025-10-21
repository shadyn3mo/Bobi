import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    @State private var isEditing = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(iconColor)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("fridge.search.placeholder".localized, text: $searchText)
                    .foregroundColor(textColor)
                    .font(.system(size: 16))
                    .onTapGesture {
                        isEditing = true
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(iconColor)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            
            if isEditing {
                Button("common.cancel".localized) {
                    isEditing = false
                    searchText = ""
                    hideKeyboard()
                }
                .foregroundColor(textColor)
                .font(.system(size: 16))
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : Color.primary
    }
    
    private var iconColor: Color {
        colorScheme == .dark ? .white.opacity(0.6) : Color.secondary
    }
    
    private var backgroundFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color(.tertiarySystemFill)
    }
    
    private var borderColor: Color {
        let opacity = isEditing ? 0.3 : 0.15
        return colorScheme == .dark ? Color.white.opacity(opacity) : Color(.separator).opacity(opacity)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        SearchBar(searchText: .constant(""))
            .padding()
    }
}