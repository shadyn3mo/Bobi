import SwiftUI

// MARK: - Action Button Models
struct ActionButtonItem: Identifiable {
    let id: String
    let systemName: String
    let color: Color
    let action: () -> Void
}

struct FloatingActionButton: View {
    let isRightHanded: Bool
    let onVoiceInput: () -> Void
    let onManualAdd: () -> Void
    let onReceiptScan: () -> Void
    
    @State private var isExpanded: Bool = false
    @Namespace private var namespace
    
    private var actionItems: [ActionButtonItem] {
        [
            ActionButtonItem(id: "voice", systemName: "mic.fill", color: .purple, action: onVoiceInput),
            ActionButtonItem(id: "manual", systemName: "pencil", color: .orange, action: onManualAdd),
            ActionButtonItem(id: "receipt", systemName: "doc.text.viewfinder", color: .blue, action: onReceiptScan)
        ]
    }
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                if isRightHanded {
                    Spacer()
                    fabContent
                } else {
                    fabContent
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }
    
    private var fabContent: some View {
        Group {
            if #available(iOS 26.0, *) {
                // iOS 26.0+ Official Liquid Glass Implementation - Complete BadgesView Copy
                GlassEffectContainer(spacing: 16.0) {
                    VStack(alignment: .center, spacing: 20.0) {
                        if isExpanded {
                            VStack(spacing: 14.0) {
                                ForEach(actionItems) { item in
                                    ActionButtonLabel(button: item)
                                        .glassEffect(.regular, in: .rect(cornerRadius: 24.0))
                                        .glassEffectID(item.id, in: namespace)
                                        .onTapGesture {
                                            withAnimation {
                                                isExpanded = false
                                            }
                                            item.action()
                                        }
                                }
                            }
                        }
                        
                        Button {
                            withAnimation {
                                isExpanded.toggle()
                            }
                        } label: {
                            ToggleButtonLabel(isExpanded: isExpanded)
                                .frame(width: 32, height: 42)
                        }
                        .buttonStyle(.glass)
                        #if os(macOS)
                        .tint(.clear)
                        #endif
                        .glassEffectID("togglebutton", in: namespace)
                    }
                    .frame(width: 74.0)
                }
            } else {
                // Backward Compatible Implementation
                backwardCompatibleFAB
            }
        }
    }
    
    // MARK: - Backward Compatible Implementation
    private var backwardCompatibleFAB: some View {
        VStack(alignment: .center, spacing: 12) {
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(actionItems) { item in
                        ActionButtonLabel(button: item)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 28)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.5),
                                                        Color.white.opacity(0.3),
                                                        Color.clear
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.6),
                                                        Color.white.opacity(0.2)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                            )
                            .scaleEffect(isExpanded ? 1.0 : 0.8)
                            .opacity(isExpanded ? 1.0 : 0.0)
                            .offset(y: isExpanded ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(actionItems.firstIndex(where: { $0.id == item.id }) ?? 0) * 0.05),
                                value: isExpanded
                            )
                            .onTapGesture {
                                withAnimation {
                                    isExpanded = false
                                }
                                item.action()
                            }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                ToggleButtonLabel(isExpanded: isExpanded)
                    .frame(width: 52, height: 62)
            }
            .buttonStyle(LegacyGlassButtonStyle())
        }
        .frame(width: 88.0)
    }
}

private struct ActionButtonLabel: View {
    let button: ActionButtonItem
    
    var body: some View {
        Image(systemName: button.systemName)
            .foregroundStyle(.white)
            .font(.system(size: 18))
            .fontWeight(.medium)
            .frame(width: 52, height: 52)
            .background(content: {
                Image(systemName: "hexagon.fill")
                    .foregroundStyle(button.color)
                    .font(.system(size: 48))
                    .frame(width: 52, height: 52)
            })
            .padding(12)
    }
}

private struct ToggleButtonLabel: View {
    let isExpanded: Bool
    
    var body: some View {
        Label(isExpanded ? "fab.hide".localized : "fab.show".localized,
              systemImage: isExpanded ? "xmark" : "leaf.fill")
            .foregroundStyle(Color.badgeShowHideColor)
            .labelStyle(.iconOnly)
            .font(.system(size: 20))
            .fontWeight(.medium)
            .imageScale(.large)
    }
}

// MARK: - Legacy Glass Button Style
private struct LegacyGlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.indigo.opacity(0.8),
                                Color.indigo.opacity(0.9),
                                Color.indigo
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: Color.indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Show Floating Button View Modifier
private struct ShowFloatingButtonViewModifier: ViewModifier {
    let isRightHanded: Bool
    let onVoiceInput: () -> Void
    let onManualAdd: () -> Void
    let onReceiptScan: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            HStack {
                if isRightHanded {
                    Spacer()
                    VStack {
                        Spacer()
                        FloatingActionButton(
                            isRightHanded: isRightHanded,
                            onVoiceInput: onVoiceInput,
                            onManualAdd: onManualAdd,
                            onReceiptScan: onReceiptScan
                        )
                        .padding()
                    }
                } else {
                    VStack {
                        Spacer()
                        FloatingActionButton(
                            isRightHanded: isRightHanded,
                            onVoiceInput: onVoiceInput,
                            onManualAdd: onManualAdd,
                            onReceiptScan: onReceiptScan
                        )
                        .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - View Extension
extension View {
    func showsFloatingButton(
        isRightHanded: Bool = true,
        onVoiceInput: @escaping () -> Void,
        onManualAdd: @escaping () -> Void,
        onReceiptScan: @escaping () -> Void
    ) -> some View {
        modifier(ShowFloatingButtonViewModifier(
            isRightHanded: isRightHanded,
            onVoiceInput: onVoiceInput,
            onManualAdd: onManualAdd,
            onReceiptScan: onReceiptScan
        ))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        FloatingActionButton(
            isRightHanded: true,
            onVoiceInput: { print("Voice input") },
            onManualAdd: { print("Manual add") },
            onReceiptScan: { print("Receipt scan") }
        )
    }
}