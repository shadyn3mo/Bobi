import SwiftUI

struct KeyboardToolbarHelper: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("common.done".localized) {
                        hideKeyboard()
                    }
                }
            }
    }
    
    @MainActor
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func keyboardToolbar() -> some View {
        self.modifier(KeyboardToolbarHelper())
    }
} 