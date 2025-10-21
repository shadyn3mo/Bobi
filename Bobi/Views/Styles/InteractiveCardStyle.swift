import SwiftUI

struct InteractiveCardStyle: ButtonStyle {
    var color: Color
    var cornerRadius: CGFloat = 24
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(cardBackgroundColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                color.opacity(colorScheme == .dark ? 0.2 : 0.15)
                            )
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private var cardBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.4)
        } else {
            return Color.white.opacity(0.8)
        }
    }
    
    private var borderColor: Color {
        color.opacity(colorScheme == .dark ? 0.3 : 0.2)
    }
} 