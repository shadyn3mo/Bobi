import SwiftUI

extension View {
    @ViewBuilder
    func glassedEffect(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            self.overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
    }
    
    @ViewBuilder
    func glassedBackground(shape: some Shape, interactive: Bool = false) -> some View {
        self.background {
            Color.clear
                .glassedEffect(in: shape, interactive: interactive)
        }
    }
}