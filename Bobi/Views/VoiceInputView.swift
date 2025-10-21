import SwiftUI
import SwiftData

struct VoiceInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var localizationManager = LocalizationManager.shared
    @State private var voiceService = VoiceInputService()
    @State private var showingParsedItems = false
    @State private var parsedItems: [ParsedFoodItem] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var currentHintIndex = 0
    @Namespace private var voiceNamespace
    
    var body: some View {
        ZStack {
            modernBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                modernTopNavigationBar
                
                // 状态显示区域 - 固定高度
                statusDisplayArea
                
                // 语音按钮区域 - 固定位置
                voiceButtonArea
                
                Spacer()
                
                modernBottomHints
            }
        }
        .sheet(isPresented: $showingParsedItems) {
                ParsedItemsReviewView(
                    parsedItems: $parsedItems,
                    onSave: { items in
                        saveParsedItems(items)
                        dismiss()
                    },
                    onCancel: {
                        showingParsedItems = false
                    }
                )
            }
        .alert("voice.error.title".localized, isPresented: $showingError) {
            Button("voice.error.ok".localized, role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: voiceService.finalRecognizedText) { _, newValue in
            if let finalText = newValue, !finalText.isEmpty {
                parseRecognizedText(from: finalText)
            }
        }
    }
    
    // MARK: - Modern UI Components
    private var modernBackgroundGradient: some View {
        ZStack {
            // 基础渐变背景
            RadialGradient(
                gradient: Gradient(colors: colorScheme == .dark
                    ? [
                        Color(red: 0.05, green: 0.1, blue: 0.25),
                        Color(red: 0.02, green: 0.05, blue: 0.15),
                        Color.black
                    ]
                    : [
                        Color(red: 0.92, green: 0.95, blue: 1.0),
                        Color(red: 0.88, green: 0.92, blue: 0.98),
                        Color(red: 0.85, green: 0.90, blue: 0.96)
                    ]
                ),
                center: .top,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height
            )
            
            // Singing view 背景图片层
            singingViewBackgroundLayer
            
            // 动态光晕效果
            if voiceService.isRecording {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                micButtonColor.opacity(0.15),
                                micButtonColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .scaleEffect(voiceService.isRecording ? 2.0 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: voiceService.isRecording)
            }
        }
    }
    
    private var singingViewBackgroundLayer: some View {
        GeometryReader { geometry in
            Image("singing_view")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .position(
                    x: geometry.size.width * 0.5,
                    y: geometry.size.height * 0.7
                )
                .opacity(voiceService.isRecording ? 0.6 : 0.3)
                .scaleEffect(voiceService.isRecording ? 1.1 : 1.0)
                .blur(radius: voiceService.isRecording ? 1 : 3)
                .animation(.easeInOut(duration: 1.5), value: voiceService.isRecording)
                .overlay {
                    if voiceService.isRecording {
                        // 动态音波扩散效果
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.cyan.opacity(0.6),
                                            Color.blue.opacity(0.4),
                                            Color.purple.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .center,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 150 + CGFloat(index * 80), height: 150 + CGFloat(index * 80))
                                .scaleEffect(voiceService.isRecording ? 1.5 + CGFloat(index) * 0.3 : 1.0)
                                .opacity(voiceService.isRecording ? 0.7 - CGFloat(index) * 0.2 : 0.0)
                                .animation(
                                    .easeInOut(duration: 2.0 + Double(index) * 0.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(index) * 0.3),
                                    value: voiceService.isRecording
                                )
                                .position(
                                    x: geometry.size.width * 0.5,
                                    y: geometry.size.height * 0.7
                                )
                        }
                        
                        // 音频可视化粒子效果
                        audioVisualizationParticles(geometry: geometry)
                    }
                }
        }
    }
    
    private func audioVisualizationParticles(geometry: GeometryProxy) -> some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince1970
            
            ForEach(0..<20, id: \.self) { index in
                let angle = Double(index) * 18.0 + time * 30
                let radius = 80 + sin(time * 2 + Double(index) * 0.5) * 20
                let offsetX = cos(angle * .pi / 180) * radius
                let offsetY = sin(angle * .pi / 180) * radius
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.cyan.opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 5
                        )
                    )
                    .frame(width: 4 + CGFloat(voiceService.audioLevel) * 8, height: 4 + CGFloat(voiceService.audioLevel) * 8)
                    .position(
                        x: geometry.size.width * 0.5 + offsetX,
                        y: geometry.size.height * 0.7 + offsetY
                    )
                    .opacity(voiceService.isRecording ? 0.9 : 0.0)
                    .blur(radius: 0.5)
            }
        }
    }
    
    private var modernTopNavigationBar: some View {
        HStack {
            // 关闭按钮 - 简化版
            Button(action: {
                voiceService.stopRecording()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(primaryTextColor)
                    .frame(width: ResponsiveDesign.ButtonSize.small, height: ResponsiveDesign.ButtonSize.small)
            }
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
            }
            
            Spacer()
            
            // 标题文本 - 简化版
            Text("voice.input.title".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(primaryTextColor)
                .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            
            Spacer()
            
            // 占位符保持居中
            Color.clear
                .frame(width: ResponsiveDesign.ButtonSize.small, height: ResponsiveDesign.ButtonSize.small)
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
        .padding(.top, 8)
    }
    
    private var statusDisplayArea: some View {
        VStack(spacing: ResponsiveDesign.Spacing.large) {
            statusTextDisplay
                .padding(.horizontal, ResponsiveDesign.Spacing.extraLarge)
                .frame(maxHeight: 180) // 减少最大高度
            
            // 音频可视化指示器
            if voiceService.isRecording {
                modernAudioIndicator
                    .frame(height: 35) // 稍微减少高度
            } else {
                Spacer().frame(height: 35) // 保持一致的占位空间
            }
        }
        .frame(height: 240) // 减少整个状态区域高度
        .padding(.top, ResponsiveDesign.Spacing.medium)
    }
    
    private var voiceButtonArea: some View {
        VStack {
            Spacer().frame(height: buttonTopSpacing) // 响应式向下移动
            modernVoiceButton
            Spacer()
        }
        .frame(height: buttonAreaHeight) // 响应式按钮区域高度
        .padding(.top, ResponsiveDesign.Spacing.large)
    }
    
    // 响应式按钮间距
    private var buttonTopSpacing: CGFloat {
        switch ResponsiveDesign.DeviceSize.current {
        case .compact: return 30
        case .regular: return 40
        case .large: return 50
        }
    }
    
    // 响应式按钮区域高度
    private var buttonAreaHeight: CGFloat {
        switch ResponsiveDesign.DeviceSize.current {
        case .compact: return 180
        case .regular: return 200
        case .large: return 220
        }
    }
    
    
    private var statusTextDisplay: some View {
        Group {
            if voiceService.authorizationStatus != .authorized {
                Text("voice.permission.required".localized)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            } else if voiceService.isRecording {
                if !voiceService.recognizedText.isEmpty {
                    ScrollView {
                        Text(voiceService.recognizedText)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(primaryTextColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                            .padding(.vertical, ResponsiveDesign.Spacing.large)
                    }
                    .frame(maxHeight: 140) // 调整滚动区域高度
                    .background {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                                .fill(.ultraThinMaterial)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large))
                        } else {
                            RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.large)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2),
                                                    Color.white.opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: voiceService.recognizedText)
                } else {
                    Text("voice.listening".localized)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.center)
                }
            } else if !voiceService.recognizedText.isEmpty {
                ScrollView {
                    Text(voiceService.recognizedText)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                        .padding(.vertical, ResponsiveDesign.Spacing.large)
                }
                .frame(maxHeight: 140) // 调整滚动区域高度
            } else {
                Text("voice.ready.to.listen".localized)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var modernAudioIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(micButtonColor)
                    .frame(width: 4, height: CGFloat.random(in: 12...32))
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: voiceService.audioLevel
                    )
            }
        }
        .opacity(voiceService.audioLevel > 0.1 ? 1.0 : 0.5)
    }
    
    private var modernVoiceButton: some View {
        Button(action: {
            if voiceService.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                micButtonColor.opacity(0.3),
                                micButtonColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: ResponsiveDesign.ButtonSize.extraLarge
                        )
                    )
                    .frame(width: ResponsiveDesign.ButtonSize.extraLarge * 1.8, height: ResponsiveDesign.ButtonSize.extraLarge * 1.8)
                    .scaleEffect(voiceService.isRecording ? 1.2 : 1.0)
                    .opacity(voiceService.isRecording ? 1.0 : 0.6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: voiceService.isRecording)
                
                // 波形视觉化
                EnhancedCircularWaveformView(audioLevel: voiceService.audioLevel, isRecording: $voiceService.isRecording)
                    .frame(width: ResponsiveDesign.ButtonSize.extraLarge * 1.4, height: ResponsiveDesign.ButtonSize.extraLarge * 1.4)
                
                // 主按钮
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    micButtonColor.lighter(by: 10),
                                    micButtonColor,
                                    micButtonColor.darker(by: 10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: ResponsiveDesign.ButtonSize.extraLarge, height: ResponsiveDesign.ButtonSize.extraLarge)
                    
                    if #available(iOS 26.0, *) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .glassEffect(.regular, in: Circle())
                            .frame(width: ResponsiveDesign.ButtonSize.extraLarge, height: ResponsiveDesign.ButtonSize.extraLarge)
                            .overlay {
                                Circle()
                                    .fill(micButtonColor.opacity(0.8))
                            }
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: ResponsiveDesign.ButtonSize.extraLarge, height: ResponsiveDesign.ButtonSize.extraLarge)
                            .overlay {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay {
                                Circle()
                                    .fill(micButtonColor.opacity(0.8))
                            }
                    }
                    
                    // 图标
                    Image(systemName: voiceService.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .shadow(color: micButtonColor.opacity(0.4), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
        .scaleEffect(voiceService.isRecording ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: voiceService.isRecording)
        .disabled(voiceService.authorizationStatus != .authorized)
    }
    
    private var modernBottomHints: some View {
        VStack(spacing: ResponsiveDesign.Spacing.medium) {
            Group {
                if voiceService.authorizationStatus != .authorized {
                    Text("voice.permission.hint".localized)
                } else if voiceService.isRecording {
                    Text(currentRecordingHint)
                } else if !voiceService.recognizedText.isEmpty {
                    Text("voice.processing.hint".localized)
                } else {
                    Text(currentTapHint)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(secondaryTextColor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, ResponsiveDesign.Spacing.large)
            .padding(.vertical, ResponsiveDesign.Spacing.small)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .glassEffect(.regular, in: Capsule())
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.1),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentHintIndex)
        }
        .padding(.horizontal, ResponsiveDesign.Spacing.large)
        .padding(.bottom, ResponsiveDesign.safeAreaBottomPadding)
    }
    
    // MARK: - Theme Properties
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark
                ? [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.05, green: 0.05, blue: 0.15)]
                : [Color(red: 0.85, green: 0.9, blue: 1.0), Color(red: 0.75, green: 0.85, blue: 0.98)]
            ),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    private var micButtonColor: Color {
        voiceService.isRecording ? .red : (colorScheme == .dark ? Color(hex: "#4A90E2") : Color.blue)
    }
    
    // MARK: - Random Hints
    private var recordingHints: [String] {
        [
            "voice.recording.hint.1",
            "voice.recording.hint.2",
            "voice.recording.hint.3",
            "voice.recording.hint.4",
            "voice.recording.hint.5",
            "voice.recording.hint.6"
        ]
    }
    
    private var tapHints: [String] {
        [
            "voice.tap.hint.1",
            "voice.tap.hint.2",
            "voice.tap.hint.3",
            "voice.tap.hint.4",
            "voice.tap.hint.5"
        ]
    }
    
    private var currentRecordingHint: String {
        recordingHints[currentHintIndex % recordingHints.count].localized
    }
    
    private var currentTapHint: String {
        tapHints[currentHintIndex % tapHints.count].localized
    }
    
    private func startRecording() {
        // 随机更换提示语句
        currentHintIndex = Int.random(in: 0..<max(recordingHints.count, tapHints.count))
        
        Task {
            do {
                try await voiceService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func stopRecording() {
        voiceService.stopRecording()
    }
    
    private func parseRecognizedText(from text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && trimmedText.count > 1 else {
            return
        }
        
        Task {
            let parser = FoodItemParser.shared
            let items = await parser.parseVoiceInput(trimmedText)
            
            await MainActor.run {
                if items.isEmpty {
                    errorMessage = "voice.parse.no.valid.food".localized
                    showingError = true
                } else {
                    self.parsedItems = items
                    showingParsedItems = true
                }
            }
        }
    }
    
    private func saveParsedItems(_ items: [ParsedFoodItem]) {
        for item in items {
            let foodItem = FoodItem(
                name: item.name,
                purchaseDate: item.purchaseDate,
                expirationDate: item.estimatedExpirationDate,
                category: item.category,
                quantity: item.quantity,
                unit: item.unit,
                specificEmoji: item.specificEmoji,
                storageLocation: item.storageLocation
            )
            
            // 设置图片数据
            if let imageData = item.imageData {
                foodItem.imageData = imageData
            }
            
            // 自动归类到合适的组
            let group = FoodGroupManager.shared.findOrCreateGroup(for: foodItem, in: modelContext)
            foodItem.group = group
            group.addItem(foodItem)
            
            modelContext.insert(foodItem)
        }
        
        do {
            try modelContext.save()
            
            // 记录购买历史
            Task {
                await HistoryRecordService.shared.recordBatchPurchase(
                    items: items,
                    in: modelContext
                )
            }
            
            // 语音添加食品后刷新通知
            Task { @MainActor in
                NotificationManager.shared.refreshNotifications()
            }
        } catch {
        }
    }
}

// 移除了 modernGlassButton 扩展方法，使用简化的玻璃效果

// MARK: - Enhanced Circular Waveform View
struct EnhancedCircularWaveformView: View {
    var audioLevel: Float
    @Binding var isRecording: Bool
    
    private let barCount = 80
    private let innerParticleCount = 30
    private let outerParticleCount = 20
    private var innerBarCount: Int { Int(Double(barCount) * 0.7) }
    
    private let primaryGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color.cyan.opacity(0.8),
            Color.blue.opacity(0.9),
            Color.purple.opacity(0.8),
            Color.pink.opacity(0.7),
            Color.cyan.opacity(0.8)
        ]),
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )
    
    private let secondaryGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color.orange.opacity(0.6),
            Color.red.opacity(0.7),
            Color.purple.opacity(0.6),
            Color.blue.opacity(0.5),
            Color.orange.opacity(0.6)
        ]),
        center: .center,
        startAngle: .degrees(180),
        endAngle: .degrees(540)
    )
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSince1970
            
            ZStack {
                enhancedOuterWaveformRing(time: time)
                enhancedInnerWaveformRing(time: time)
                
                if isRecording {
                    enhancedParticleEffects(time: time)
                    enhancedCentralPulse
                }
            }
            .animation(.easeInOut(duration: 0.1), value: audioLevel)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isRecording)
        }
    }
    
    private func enhancedOuterWaveformRing(time: Double) -> some View {
        ForEach(0..<barCount, id: \.self) { index in
            let barHeight = self.outerBarHeight(for: index, time: time)
            let rotationAngle = Double(index) * 360.0 / Double(barCount)
            
            Rectangle()
                .fill(primaryGradient)
                .frame(width: 2.5, height: barHeight)
                .offset(y: -60)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(isRecording ? 1.0 : 0.3)
        }
    }
    
    private func enhancedInnerWaveformRing(time: Double) -> some View {
        ForEach(0..<innerBarCount, id: \.self) { index in
            let barHeight = self.innerBarHeight(for: index, time: time)
            let rotationAngle = Double(index) * 360.0 / Double(innerBarCount)
            
            Rectangle()
                .fill(secondaryGradient)
                .frame(width: 2, height: barHeight)
                .offset(y: -40)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(isRecording ? 0.8 : 0.2)
        }
    }
    
    private func enhancedParticleEffects(time: Double) -> some View {
        ZStack {
            enhancedInnerParticles(time: time)
            enhancedOuterParticles(time: time)
        }
    }
    
    private func enhancedInnerParticles(time: Double) -> some View {
        ForEach(0..<innerParticleCount, id: \.self) { index in
            let angle = Angle(degrees: (Double(index) / Double(innerParticleCount)) * 360 - time * 80)
            let radius = 30 + sin(time * 2 + Double(index) * 0.3) * 5
            let offsetX = cos(angle.radians) * radius
            let offsetY = sin(angle.radians) * radius
            
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 3, height: 3)
                .offset(x: offsetX, y: offsetY)
                .blur(radius: 0.5)
        }
    }
    
    private func enhancedOuterParticles(time: Double) -> some View {
        ForEach(0..<outerParticleCount, id: \.self) { index in
            let angle = Angle(degrees: (Double(index) / Double(outerParticleCount)) * 360 + time * 40)
            let radius = 45 + cos(time * 1.5 + Double(index) * 0.4) * 8
            let offsetX = cos(angle.radians) * radius
            let offsetY = sin(angle.radians) * radius
            
            Circle()
                .fill(Color.cyan.opacity(0.6))
                .frame(width: 2, height: 2)
                .offset(x: offsetX, y: offsetY)
                .blur(radius: 0.3)
        }
    }
    
    private var enhancedCentralPulse: some View {
        ZStack {
            let audioLevelCG = CGFloat(audioLevel)
            
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .frame(width: 20 + audioLevelCG * 40, height: 20 + audioLevelCG * 40)
                .scaleEffect(1.0 + audioLevelCG * 0.5)
                .opacity(0.7 - audioLevelCG * 0.3)
            
            Circle()
                .stroke(Color.cyan.opacity(0.3), lineWidth: 0.5)
                .frame(width: 30 + audioLevelCG * 60, height: 30 + audioLevelCG * 60)
                .scaleEffect(1.0 + audioLevelCG * 0.3)
                .opacity(0.5 - audioLevelCG * 0.2)
        }
    }
    
    private func outerBarHeight(for index: Int, time: Double) -> CGFloat {
        let idleHeight: CGFloat = 4
        guard isRecording else { return idleHeight }
        
        let phaseShift = time * 4
        let wave1 = sin((Double(index) / Double(barCount)) * .pi * 6 + phaseShift)
        let wave2 = sin((Double(index) / Double(barCount)) * .pi * 12 + phaseShift * 1.5)
        let wave3 = cos((Double(index) / Double(barCount)) * .pi * 8 + phaseShift * 0.8)
        
        let combinedWave = (wave1 + wave2 * 0.7 + wave3 * 0.5) / 2.2
        let dynamicHeight = CGFloat(audioLevel) * 35 * abs(CGFloat(combinedWave))
        
        return idleHeight + dynamicHeight
    }
    
    private func innerBarHeight(for index: Int, time: Double) -> CGFloat {
        let idleHeight: CGFloat = 3
        guard isRecording else { return idleHeight }
        
        let phaseShift = time * 5
        let barCountAdjusted = Int(Double(barCount) * 0.7)
        let indexRatio = Double(index) / Double(barCountAdjusted)
        let wave1 = cos(indexRatio * .pi * 8 + phaseShift)
        let wave2 = sin(indexRatio * .pi * 14 + phaseShift * 1.3)
        
        let combinedWave = (wave1 + wave2 * 0.8) / 1.8
        let dynamicHeight = CGFloat(audioLevel) * 25 * abs(CGFloat(combinedWave))
        
        return idleHeight + dynamicHeight
    }
}

struct ParsedItemsReviewView: View {
    @Binding var parsedItems: [ParsedFoodItem]
    var onSave: ([ParsedFoodItem]) -> Void
    var onCancel: () -> Void
    
    @State private var itemToEdit: ParsedFoodItem?
    
    init(parsedItems: Binding<[ParsedFoodItem]>, onSave: @escaping ([ParsedFoodItem]) -> Void, onCancel: @escaping () -> Void) {
        self._parsedItems = parsedItems
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach($parsedItems) { $item in
                    ParsedItemRowView(item: $item)
                        .onTapGesture {
                            self.itemToEdit = item
                        }
                }
                .onDelete { indexSet in
                    parsedItems.remove(atOffsets: indexSet)
                }
            }
            .navigationTitle("voice.review.title".localized)
            .standardEditingToolbar(
                onCancel: { onCancel() },
                onSave: { onSave(parsedItems) },
                saveEnabled: !parsedItems.isEmpty,
                hasInput: !parsedItems.isEmpty
            )
            .sheet(item: $itemToEdit) { item in
                // Find the binding to the item in the array to ensure edits are saved.
                if let index = parsedItems.firstIndex(where: { $0.id == item.id }) {
                    EditParsedItemView(item: $parsedItems[index])
                }
            }
        }
    }
}

struct ParsedItemRowView: View {
    @Binding var item: ParsedFoodItem
    @State private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        HStack {
            // 显示图片或图标
            if let imageData = item.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(item.displayIcon)
                    .font(.title)
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.quantity) \(item.effectiveDisplayUnit) \(item.name)")
                    .font(.headline)
                
                // 体积输入提示
                if item.needsVolumeInput {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("voice.volume.input.required".localized)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Text("food.details.purchase.date".localized + ": " + DateFormatter.shortDate.string(from: item.purchaseDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let expirationDate = item.estimatedExpirationDate {
                    Text("voice.review.expires".localized(with: DateFormatter.shortDate.string(from: expirationDate)))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Image(systemName: "pencil.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title2)
        }
        .padding(.vertical, 8)
    }
}

// Helper Extensions
extension DateFormatter {
    static var shortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        // Set locale based on current language
        let languageCode = LocalizationManager.shared.selectedLanguage
        if languageCode == "zh-Hans" {
            formatter.locale = Locale(identifier: "zh_CN")
        } else {
            formatter.locale = Locale(identifier: "en_US")
        }
        return formatter
    }
}

#Preview {
    VoiceInputView()
        .modelContainer(for: FoodItem.self, inMemory: true)
}