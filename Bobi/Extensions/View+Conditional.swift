import SwiftUI

extension View {
    /// 条件性地应用修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 点击空白区域关闭键盘
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    /// 添加手势来关闭键盘（兼容Form和List）
    func dismissKeyboardOnTap() -> some View {
        self.gesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }
    
    /// 为ScrollView和其他容器添加键盘关闭功能
    func keyboardDismissible() -> some View {
        self.scrollDismissesKeyboard(.interactively)
    }
}