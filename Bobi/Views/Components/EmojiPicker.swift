import SwiftUI

struct EmojiPicker: View {
    @Binding var selectedEmoji: String?
    @Environment(\.dismiss) private var dismiss
    @State private var localizationManager = LocalizationManager.shared
    
    private let emojis = [
        // 水果
        "🍎", "🍏", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅",
        
        // 蔬菜
        "🥕", "🌽", "🌶️", "🫑", "🥒", "🥬", "🥦", "🧄", "🧅", "🍄", "🥔", "🍠", "🫒", "🥑", "🍆", "🥙",
        
        // 肉类和海鲜
        "🥩", "🍗", "🥓", "🌭", "🍖", "🦴", "🐟", "🦐", "🦀", "🦞", "🦑", "🐙", "🦆", "🦃", "🐔", "🐷", "🐮", "🐑",
        
        // 乳制品和蛋类
        "🥛", "🧀", "🧈", "🥚", "🍳",
        
        // 谷物和面包
        "🍞", "🥖", "🥨", "🥯", "🥐", "🧇", "🥞", "🍚", "🍙", "🍘", "🍜", "🍝", "🥗", "🌾", "🥣",
        
        // 甜点和零食
        "🍰", "🧁", "🥧", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🍦", "🍧", "🧊",
        
        // 饮料
        "☕", "🍵", "🥤", "🧃", "🍼", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🧉", "🧋",
        
        // 调料和香料
        "🧂", "🫚", "🥄", "🍴", "🥢",
        
        // 容器和包装
        "🥫", "🍱", "🍽️", "🥡", "🧺", "📦", "🎒", "👜", "🛒",
        
        // 其他相关
        "❄️", "🔥", "⭐", "💚", "❤️", "🟢", "🔴", "🟡", "🟠", "🟣", "🔵", "⚫", "⚪", "🟤"
    ]
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: ResponsiveDesign.GridColumns.emoji)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 当前选择显示
                VStack(spacing: 16) {
                    if let emoji = selectedEmoji {
                        Text(emoji)
                            .font(.system(size: 80))
                        Text("emoji.picker.current.selection".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("emoji.picker.select.prompt".localized)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Emoji网格
                ScrollView {
                    LazyVGrid(columns: columns, spacing: ResponsiveDesign.Spacing.small) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                                dismiss()
                            }) {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: ResponsiveDesign.ButtonSize.small, height: ResponsiveDesign.ButtonSize.small)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedEmoji == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                
                // 重置按钮
                if selectedEmoji != nil {
                    Button(action: {
                        selectedEmoji = nil
                        dismiss()
                    }) {
                        Text("edit.group.use.default.icon".localized)
                            .foregroundColor(.blue)
                            .padding()
                    }
                }
            }
            .navigationTitle("emoji.picker.title".localized)
            .standardEditingToolbar(
                onCancel: { dismiss() },
                onSave: { dismiss() },
                saveEnabled: selectedEmoji != nil,
                hasInput: selectedEmoji != nil
            )
        }
    }
}

#Preview {
    EmojiPicker(selectedEmoji: .constant("🍎"))
        
}