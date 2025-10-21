import SwiftUI
import VisionKit
import Vision

enum ParseMethod {
    case ai
    case traditional
}

struct ReceiptScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingDocumentScanner = false
    @State private var isProcessing = false
    @State private var recognizedText = ""
    @State private var parsedReceipt: ParsedReceipt?
    @State private var showingReviewView = false
    @State private var isAddingItems = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var showingEditView = false
    @State private var showingDailyLimitAlert = false
    
    // 动画状态变量
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var imageScale: CGFloat = 1.0
    @State private var dotScales: [CGFloat] = [1.0, 1.0, 1.0]
    
    enum ScanningMode {
        case camera, photoLibrary
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isProcessing {
                    processingView
                } else if parsedReceipt != nil {
                    reviewView
                } else {
                    scanningView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("receipt.scan.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .standardCancelToolbar(onCancel: { dismiss() })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage) { image in
                if let image = image {
                    processImage(image)
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            if let receipt = parsedReceipt {
                ReceiptEditView(
                    receipt: Binding(
                        get: { receipt },
                        set: { updatedReceipt in
                            parsedReceipt = updatedReceipt
                        }
                    ),
                    onSave: {
                        Task {
                            await addItemsToFridge()
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingDocumentScanner) {
            DocumentCameraWrapper { images in
                if !images.isEmpty {
                    processMultipleImages(images)
                }
            }
        }
        .alert("ai.daily.limit.exceeded".localized, isPresented: $showingDailyLimitAlert) {
            Button("common.done".localized) {
                // 关闭弹窗，返回扫描页面
            }
        } message: {
            Text("ai.daily.limit.exceeded.detail".localized)
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                
                Text("receipt.scan.instruction".localized)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text("receipt.scan.description".localized)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 扫描提示
                VStack(spacing: 12) {
                    scanTipView(icon: "checkmark.circle", text: "receipt.scan.tip.focus".localized, isRecommended: true)
                    scanTipView(icon: "checkmark.circle", text: "receipt.scan.tip.straight".localized, isRecommended: true)
                    scanTipView(icon: "checkmark.circle", text: "receipt.scan.tip.clear".localized, isRecommended: true)
                    scanTipView(icon: "checkmark.circle", text: "receipt.scan.tip.multiple".localized, isRecommended: true)
                    scanTipView(icon: "x.circle", text: "receipt.scan.tip.angle".localized, isRecommended: false)
                }
                .padding(.top, 16)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                scanButton(mode: .camera)
                scanButton(mode: .photoLibrary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private func scanTipView(icon: String, text: String, isRecommended: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isRecommended ? .green : .red)
                .frame(width: 24)
            
            Text(text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isRecommended ? .primary : .secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isRecommended ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecommended ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    private func scanButton(mode: ScanningMode) -> some View {
        Button(action: {
            switch mode {
            case .camera:
                if VNDocumentCameraViewController.isSupported {
                    showingDocumentScanner = true
                } else {
                    showingImagePicker = true
                }
            case .photoLibrary:
                showingImagePicker = true
            }
        }) {
            HStack {
                Image(systemName: mode == .camera ? "camera.fill" : "photo.on.rectangle")
                    .font(.title3)
                Text(mode == .camera ? "receipt.scan.camera".localized : "receipt.scan.photo".localized)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.blue)
            .cornerRadius(16)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                // 智能文档处理动画
                ZStack {
                    // 外层脉冲圆圈
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
                    
                    // 内层旋转圆环
                    Circle()
                        .stroke(Color.blue.opacity(0.4), lineWidth: 3)
                        .frame(width: 130, height: 130)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, lineWidth: 4)
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: rotationAngle)
                    
                    // 中心working_view图片
                    Image("working_view")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .scaleEffect(imageScale)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: imageScale)
                }
                
                // 动态加载点
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotScales[index])
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: dotScales[index]
                            )
                    }
                }
                
                Text("receipt.scan.processing".localized)
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("receipt.scan.processing.description".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .onAppear {
            startProcessingAnimation()
        }
        .onDisappear {
            stopProcessingAnimation()
        }
    }
    
    private func startProcessingAnimation() {
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            imageScale = 1.2
        }
        
        // 启动点的动画
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.2)
            ) {
                dotScales[i] = 1.5
            }
        }
    }
    
    private func stopProcessingAnimation() {
        rotationAngle = 0
        pulseScale = 1.0
        imageScale = 1.0
        dotScales = [1.0, 1.0, 1.0]
    }
    
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let receipt = parsedReceipt {
                    receiptInfoCard(receipt)
                    itemsListCard(receipt.items)
                    confirmationButtons
                }
            }
            .padding()
        }
    }
    
    private func receiptInfoCard(_ receipt: ParsedReceipt) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("receipt.scan.date".localized)
                .font(.headline)
                .foregroundColor(.primary)
            
            DatePicker("", selection: Binding(
                get: { receipt.purchaseDate },
                set: { newDate in
                    var updatedReceipt = receipt
                    updatedReceipt.purchaseDate = newDate
                    parsedReceipt = updatedReceipt
                }
            ), displayedComponents: .date)
            .datePickerStyle(.compact)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func itemsListCard(_ items: [ParsedReceiptItem]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("receipt.scan.items".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                Text("\(items.count) \("receipt.scan.items.count".localized)")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if items.isEmpty {
                // 显示空状态
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("receipt.scan.no_food_items".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("receipt.scan.no_food_items.description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                List {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    if let quantity = item.quantity {
                                        Text("\("common.quantity".localized): \(quantity)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.visible)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                removeItemByName(item.name)
                            } label: {
                                Label("common.delete".localized, systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(minHeight: max(CGFloat(items.count) * 60, 100))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var confirmationButtons: some View {
        VStack(spacing: 12) {
            // 只有在有项目时才显示编辑按钮
            if let receipt = parsedReceipt, !receipt.items.isEmpty {
                Button(action: {
                    showingEditView = true
                }) {
                    Text("receipt.edit.button".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                
                Button(action: confirmAndAddItems) {
                    HStack {
                        if isAddingItems {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                            Text("receipt.scan.adding".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Text("receipt.add.direct".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isAddingItems ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isAddingItems)
            }
            
            // 总是显示重新扫描按钮
            if !isAddingItems {
                Button(action: { parsedReceipt = nil }) {
                    Text("receipt.scan.retry".localized)
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
        }
        .alert("receipt.scan.result".localized, isPresented: $showingAlert) {
            Button("common.done".localized) {
                if parsedReceipt?.items.isEmpty == true {
                    // 如果没有项目，关闭弹窗后重新扫描
                    parsedReceipt = nil
                }
                // 如果有项目，只关闭 alert，让用户继续查看和编辑扫描结果
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func processMultipleImages(_ images: [UIImage]) {
        isProcessing = true
        
        Task {
            var allParsedItems: [ParsedReceiptItem] = []
            var successCount = 0
            var failureCount = 0
            var aiSuccessCount = 0
            var traditionalCount = 0
            
            for (index, image) in images.enumerated() {
                do {
                    print("🔍 处理第 \(index + 1)/\(images.count) 张收据图片")
                    let text = try await performOCR(on: image)
                    print("📝 第 \(index + 1) 张图片 OCR 完成，识别文本长度: \(text.count)")
                    
                    let receipt = try await ReceiptParser.shared.parseReceipt(from: text)
                    print("✅ 第 \(index + 1) 张收据解析完成，项目数量: \(receipt.items.count)")
                    
                    allParsedItems.append(contentsOf: receipt.items)
                    successCount += 1
                    
                    // 统计解析方法
                    if receipt.parseMethod == .ai {
                        aiSuccessCount += 1
                    } else {
                        traditionalCount += 1
                    }
                } catch {
                    print("❌ 处理第 \(index + 1) 张收据失败: \(error)")
                    failureCount += 1
                    
                    // 如果是每日限制错误，立即停止处理并显示错误
                    if let aiError = error as? AIServiceError, case .dailyLimitExceeded = aiError {
                        await MainActor.run {
                            isProcessing = false
                            showingDailyLimitAlert = true
                        }
                        return
                    }
                }
            }
            
            await MainActor.run {
                isProcessing = false
                
                // 创建合并收据（即使为空也要创建，让用户看到处理结果）
                let combinedReceipt = ParsedReceipt(
                    purchaseDate: Date(),
                    items: allParsedItems
                )
                parsedReceipt = combinedReceipt
                
                // 根据处理结果显示不同的提示信息
                if successCount == 0 {
                    // 所有收据都处理失败
                    alertMessage = "receipt.scan.all_failed".localized
                        .replacingOccurrences(of: "{count}", with: "\(images.count)")
                    showingAlert = true
                } else if allParsedItems.isEmpty {
                    // 处理成功但没找到食材
                    var message = "receipt.scan.no_items_found_multiple".localized
                        .replacingOccurrences(of: "{processed}", with: "\(successCount)")
                        .replacingOccurrences(of: "{total}", with: "\(images.count)")
                    
                    // 添加解析方法信息
                    if traditionalCount > 0 {
                        message += "\n" + "receipt.scan.traditional_method_used".localized
                            .replacingOccurrences(of: "{count}", with: "\(traditionalCount)")
                    }
                    
                    alertMessage = message
                    showingAlert = true
                } else if failureCount > 0 {
                    // 部分成功
                    var message = "receipt.scan.partial_success".localized
                        .replacingOccurrences(of: "{success}", with: "\(successCount)")
                        .replacingOccurrences(of: "{total}", with: "\(images.count)")
                        .replacingOccurrences(of: "{items}", with: "\(allParsedItems.count)")
                    
                    // 添加解析方法信息
                    if traditionalCount > 0 {
                        message += "\n" + "receipt.scan.traditional_method_used".localized
                            .replacingOccurrences(of: "{count}", with: "\(traditionalCount)")
                    }
                    
                    alertMessage = message
                    showingAlert = true
                } else if images.count > 1 {
                    // 全部成功处理多张收据
                    var message = "receipt.scan.multiple_success".localized
                        .replacingOccurrences(of: "{count}", with: "\(images.count)")
                        .replacingOccurrences(of: "{items}", with: "\(allParsedItems.count)")
                    
                    // 添加解析方法信息
                    if traditionalCount > 0 && aiSuccessCount > 0 {
                        message += "\n" + "receipt.scan.mixed_methods".localized
                            .replacingOccurrences(of: "{ai}", with: "\(aiSuccessCount)")
                            .replacingOccurrences(of: "{traditional}", with: "\(traditionalCount)")
                    } else if traditionalCount > 0 {
                        message += "\n" + "receipt.scan.traditional_method_used".localized
                            .replacingOccurrences(of: "{count}", with: "\(traditionalCount)")
                    }
                    
                    alertMessage = message
                    showingAlert = true
                } else if traditionalCount > 0 {
                    // 单张收据使用传统方法
                    alertMessage = "receipt.scan.single_traditional".localized
                    showingAlert = true
                }
                // AI 成功的单张收据不显示 alert，直接进入审核页面
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        
        Task {
            do {
                let text = try await performOCR(on: image)
                print("🔍 OCR 完成，识别文本长度: \(text.count)")
                print("📝 OCR 识别内容前500字符: \(String(text.prefix(500)))")
                
                let receipt = try await ReceiptParser.shared.parseReceipt(from: text)
                print("✅ 收据解析完成，项目数量: \(receipt.items.count)")
                
                await MainActor.run {
                    isProcessing = false
                    // 即使没有找到食品项目，也要显示结果页面让用户知道
                    if receipt.items.isEmpty {
                        // 创建一个空的收据对象，但仍然进入reviewView
                        parsedReceipt = receipt
                        alertMessage = "receipt.scan.no_items_found".localized
                        showingAlert = true
                    } else {
                        parsedReceipt = receipt
                    }
                }
            } catch {
                print("❌ 处理图片失败: \(error)")
                await MainActor.run {
                    isProcessing = false
                    
                    // 专门处理每日限制错误
                    if let aiError = error as? AIServiceError {
                        switch aiError {
                        case .dailyLimitExceeded:
                            showingDailyLimitAlert = true
                        default:
                            alertMessage = handleError(error)
                            showingAlert = true
                        }
                    } else {
                        alertMessage = handleError(error)
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func performOCR(on image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: ReceiptScanError.invalidImage)
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ReceiptScanError.ocrFailed)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case ReceiptScanError.invalidImage:
            return "receipt.error.invalid_data".localized
        case ReceiptScanError.ocrFailed:
            return "receipt.error.ocr.quality".localized
        case ReceiptScanError.parsingFailed:
            return "receipt.error.processing.failed".localized
        default:
            return error.localizedDescription
        }
    }
    
    private func removeItemByName(_ name: String) {
        guard var receipt = parsedReceipt else { return }
        receipt.items.removeAll { $0.name == name }
        parsedReceipt = receipt
    }
    
    private func deleteItems(at offsets: IndexSet) {
        guard var receipt = parsedReceipt else { return }
        receipt.items.remove(atOffsets: offsets)
        parsedReceipt = receipt
    }
    
    private func confirmAndAddItems() {
        guard let receipt = parsedReceipt else { 
            alertMessage = "receipt.error.no_data".localized
            showingAlert = true
            return 
        }
        
        // 检查是否有有效的食品项目
        if receipt.items.isEmpty {
            alertMessage = "receipt.error.no_food_items".localized
            showingAlert = true
            return
        }
        
        isAddingItems = true
        
        Task {
            await addItemsToFridge()
        }
    }
    
    private func addItemsToFridge() async {
        guard let receipt = parsedReceipt else { return }
        
        await MainActor.run {
            isAddingItems = true
        }
        
        // 转换收据项目为ParsedFoodItem
        let parsedItems = receipt.items.map { receiptItem in
            convertToFoodItem(receiptItem, purchaseDate: receipt.purchaseDate)
        }
        
        // 使用现有的处理逻辑
        await processParsedItems(parsedItems)
        
        await MainActor.run {
            isAddingItems = false
            showingAlert = true
            alertMessage = "receipt.success.items_added".localized
                .replacingOccurrences(of: "{count}", with: "\(parsedItems.count)")
        }
    }
    
    private func convertToFoodItem(_ receiptItem: ParsedReceiptItem, purchaseDate: Date) -> ParsedFoodItem {
        // 解析数量和单位
        let (quantity, unit) = parseQuantityAndUnit(receiptItem.quantity ?? "1")
        
        // 解析分类
        let category = parseCategory(receiptItem.category ?? "其他")
        
        // 推荐存储位置
        let storageLocation = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: receiptItem.name, category: category)
        
        // 估算过期日期
        let shelfLifeDays = StorageLocationRecommendationEngine.shared.getShelfLifeDays(for: receiptItem.name, category: category, storageLocation: storageLocation)
        let estimatedExpiry = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: purchaseDate)
        
        return ParsedFoodItem(
            name: receiptItem.name,
            quantity: quantity,
            unit: unit,
            category: category,
            purchaseDate: purchaseDate,
            estimatedExpirationDate: estimatedExpiry,
            recommendedStorageLocation: storageLocation,
            storageLocation: storageLocation
        )
    }
    
    private func parseQuantityAndUnit(_ quantityString: String) -> (Int, String) {
        // 简单的数量解析
        let trimmed = quantityString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 提取数字
        let numberRegex = try? NSRegularExpression(pattern: "\\d+", options: [])
        if let match = numberRegex?.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.count)) {
            let numberString = String(trimmed[Range(match.range, in: trimmed)!])
            let quantity = Int(numberString) ?? 1
            
            // 简单的单位检测
            let lowerTrimmed = trimmed.lowercased()
            if lowerTrimmed.contains("kg") || lowerTrimmed.contains("公斤") {
                return (quantity * 1000, "g")
            } else if lowerTrimmed.contains("g") || lowerTrimmed.contains("克") {
                return (quantity, "g")
            } else if lowerTrimmed.contains("ml") || lowerTrimmed.contains("毫升") {
                return (quantity, "mL")
            } else if lowerTrimmed.contains("l") || lowerTrimmed.contains("升") {
                return (quantity * 1000, "mL")
            }
            
            return (quantity, FoodItem.defaultUnit)
        }
        
        return (1, FoodItem.defaultUnit)
    }
    
    private func parseCategory(_ categoryString: String) -> FoodCategory {
        let lower = categoryString.lowercased()
        
        // 简单的分类映射 - 中英文支持
        if lower.contains("牛奶") || lower.contains("奶") || lower.contains("酸奶") ||
           lower.contains("milk") || lower.contains("dairy") || lower.contains("yogurt") || lower.contains("cheese") {
            return .dairy
        } else if lower.contains("肉") || lower.contains("牛") || lower.contains("猪") || lower.contains("鸡") ||
                  lower.contains("meat") || lower.contains("beef") || lower.contains("pork") || lower.contains("chicken") || lower.contains("lamb") {
            return .meat
        } else if lower.contains("菜") || lower.contains("蔬") ||
                  lower.contains("vegetable") || lower.contains("lettuce") || lower.contains("cabbage") || lower.contains("spinach") {
            return .vegetables
        } else if lower.contains("果") || lower.contains("苹果") || lower.contains("香蕉") ||
                  lower.contains("fruit") || lower.contains("apple") || lower.contains("banana") || lower.contains("orange") {
            return .fruits
        } else if lower.contains("蛋") ||
                  lower.contains("egg") {
            return .eggs
        } else if lower.contains("鱼") || lower.contains("虾") ||
                  lower.contains("fish") || lower.contains("seafood") || lower.contains("shrimp") || lower.contains("salmon") {
            return .seafood
        } else if lower.contains("饮") || lower.contains("水") || lower.contains("汁") ||
                  lower.contains("drink") || lower.contains("beverage") || lower.contains("juice") || lower.contains("water") {
            return .beverages
        } else if lower.contains("米") || lower.contains("面") || lower.contains("包") ||
                  lower.contains("rice") || lower.contains("noodle") || lower.contains("bread") || lower.contains("grain") {
            return .grains
        } else if lower.contains("罐头") ||
                  lower.contains("canned") || lower.contains("can") {
            return .canned
        } else if lower.contains("零食") || lower.contains("饼干") ||
                  lower.contains("snack") || lower.contains("cookie") || lower.contains("chip") {
            return .snacks
        } else if lower.contains("调料") || lower.contains("盐") || lower.contains("糖") ||
                  lower.contains("condiment") || lower.contains("salt") || lower.contains("sugar") || lower.contains("sauce") {
            return .condiments
        } else if lower.contains("冷冻") ||
                  lower.contains("frozen") {
            return .frozen
        }
        
        return .other
    }
    
    private func processParsedItems(_ items: [ParsedFoodItem]) async {
        // 这里应该调用现有的处理逻辑，类似于 VoiceInputView 中的处理
        // 为了简化，直接使用 ReceiptProcessor
        do {
            let receipt = ParsedReceipt(
                purchaseDate: items.first?.purchaseDate ?? Date(),
                items: items.map { item in
                    ParsedReceiptItem(
                        name: item.name,
                        quantity: "\(item.quantity) \(item.unit)",
                        category: item.category.localizedName
                    )
                }
            )
            
            _ = try await ReceiptProcessor.shared.addItemsFromReceipt(receipt, modelContext: modelContext)
        } catch {
            print("❌ Error processing items: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct ParsedReceiptItem {
    let name: String
    let quantity: String?
    let category: String?
}

struct ParsedReceipt {
    var purchaseDate: Date
    var items: [ParsedReceiptItem]
    var parseMethod: ParseMethod = .ai
}


enum ReceiptScanError: Error {
    case invalidImage
    case ocrFailed
    case parsingFailed
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let completion: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.completion(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Camera

struct DocumentCameraWrapper: UIViewControllerRepresentable {
    let onImagesCaptured: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraWrapper
        
        init(_ parent: DocumentCameraWrapper) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                if isValidReceiptImage(image) {
                    images.append(image)
                }
            }
            
            parent.onImagesCaptured(images)
            parent.dismiss()
        }
        
        private func isValidReceiptImage(_ image: UIImage) -> Bool {
            let minArea = 50000.0 // 最小像素面积
            let imageArea = Double(image.size.width * image.size.height)
            let minWidth = 200.0
            let minHeight = 300.0
            let actualWidth = image.size.width * image.scale
            let actualHeight = image.size.height * image.scale
            
            return imageArea >= minArea && 
                   actualWidth >= minWidth && 
                   actualHeight >= minHeight
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("❌ DocumentCamera error: \(error)")
            parent.dismiss()
        }
    }
}

#Preview {
    ReceiptScanView()
}