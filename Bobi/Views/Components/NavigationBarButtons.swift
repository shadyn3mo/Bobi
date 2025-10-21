import SwiftUI

// MARK: - Toolbar Modifier Extensions
extension View {
    func standardEditingToolbar(
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        saveEnabled: Bool = true,
        hasInput: Bool = false
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(!saveEnabled)
                }
            }
    }
    
    func standardCancelToolbar(
        onCancel: @escaping () -> Void
    ) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
    }
}
