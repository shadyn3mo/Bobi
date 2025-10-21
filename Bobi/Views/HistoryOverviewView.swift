import SwiftUI
import SwiftData

struct HistoryOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \FoodHistoryRecord.date, order: .reverse) private var allRecords: [FoodHistoryRecord]
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedRecordType: RecordTypeFilter = .all
    @State private var statistics: HistoryStatistics?
    @State private var isLoading = true
    @State private var showingClearAlert = false
    
    enum TimeRange: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"
        
        var displayName: String {
            switch self {
            case .today: return "history.time.today".localized
            case .week: return "history.time.week".localized
            case .month: return "history.time.month".localized
            }
        }
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                let startOfToday = calendar.startOfDay(for: now)
                return (startOfToday, now)
            case .week:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                return (startOfWeek, now)
            case .month:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return (startOfMonth, now)
            }
        }
    }
    
    enum RecordTypeFilter: String, CaseIterable {
        case all = "all"
        case purchase = "purchase"
        case recipeMade = "recipeMade"
        case expiration = "expiration"
        
        var displayName: String {
            switch self {
            case .all: return "history.filter.all".localized
            case .purchase: return "history.type.purchase".localized
            case .recipeMade: return "history.type.recipeMade".localized
            case .expiration: return "history.type.expiration".localized
            }
        }
        
        var recordType: FoodHistoryRecord.RecordType? {
            switch self {
            case .all: return nil
            case .purchase: return .purchase
            case .recipeMade: return .consumption // 特殊处理：需要额外检查recipeName
            case .expiration: return .expiration
            }
        }
        
        var needsRecipeNameCheck: Bool {
            return self == .recipeMade
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .purchase: return .green
            case .recipeMade: return .orange
            case .expiration: return .red
            }
        }
    }
    
    var filteredRecords: [FoodHistoryRecord] {
        let range = selectedTimeRange.dateRange
        return allRecords.filter { record in
            let inDateRange = record.date >= range.start && record.date <= range.end
            
            switch selectedRecordType {
            case .all:
                return inDateRange
            case .recipeMade:
                // 制作菜品：显示所有消耗记录（包括有无菜谱名的）
                return inDateRange && record.type == .consumption
            case .purchase, .expiration:
                // 其他类型正常筛选
                return inDateRange && record.type == selectedRecordType.recordType
            }
        }
    }
    
    var groupedRecords: [(date: Date, records: [FoodHistoryRecord])] {
        guard !isLoading && !filteredRecords.isEmpty else {
            return []
        }
        
        if selectedRecordType == .recipeMade {
            // 对于制作菜品，按菜谱名分组，但仍返回Date类型以保持接口一致
            let recipeGroups = Dictionary(grouping: filteredRecords) { record in
                record.recipeName ?? "Unknown Recipe"
            }
            
            return recipeGroups.compactMap { (recipeName, records) in
                // 使用该菜谱最新的制作日期作为组的日期
                guard let latestDate = records.map({ $0.date }).max() else { return nil }
                return (date: latestDate, records: records.sorted { $0.date > $1.date })
            }
            .sorted { $0.date > $1.date }
        } else {
            // 其他类型按日期分组
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: filteredRecords) { record in
                calendar.startOfDay(for: record.date)
            }
            
            return grouped.map { (date: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
                .sorted { $0.date > $1.date }
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // 背景
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 顶部标题区域
                            headerSection
                            
                            // 时间范围和筛选器
                            filtersSection
                            
                            // 统计卡片区域
                            if let stats = statistics {
                                statisticsSection(stats)
                            }
                            
                            // 记录列表
                            recordsListSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("history.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // 说明信息
                        Text("history.cleanup.auto.info".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Button("history.cleanup.all".localized, systemImage: "trash", role: .destructive) {
                            showingClearAlert = true
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .task {
            await loadStatistics()
        }
        .onChange(of: selectedTimeRange) { _, _ in
            Task {
                await loadStatistics()
            }
        }
        .onChange(of: selectedRecordType) { _, _ in
            Task {
                await loadStatistics()
            }
        }
        .onChange(of: allRecords.count) { _, _ in
            // When the record count changes (like after clearing), reload statistics
            Task {
                await loadStatistics()
            }
        }
        .alert("history.cleanup.confirm.title".localized, isPresented: $showingClearAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("history.cleanup.confirm.button".localized, role: .destructive) {
                Task {
                    isLoading = true
                    await HistoryRecordService.shared.clearAllRecords(in: modelContext)
                    
                    // Give SwiftData time to update the query
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    
                    await loadStatistics()
                    isLoading = false
                }
            }
        } message: {
            Text("history.cleanup.confirm.message".localized)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("history.overview.title".localized)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("history.overview.subtitle".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Filters Section
    
    private var filtersSection: some View {
        VStack(spacing: 16) {
            // 时间范围选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedTimeRange = range
                        }) {
                            Text(range.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedTimeRange == range ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedTimeRange == range ? Color.blue : Color.secondary.opacity(0.15))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // 记录类型筛选器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecordTypeFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedRecordType = filter
                        }) {
                            Text(filter.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedRecordType == filter ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedRecordType == filter ? filter.color : Color.secondary.opacity(0.15))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private func statisticsSection(_ stats: HistoryStatistics) -> some View {
        VStack(spacing: 12) {
            Text("history.statistics.title".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 紧凑的统计卡片 - 2x2布局
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    CompactStatCard(
                        title: "history.stats.purchases".localized,
                        value: "\(stats.totalPurchaseCount)",
                        icon: "cart.fill",
                        color: .green
                    )
                    
                    CompactStatCard(
                        title: "history.stats.dishes".localized,
                        value: "\(stats.uniqueRecipesCount)",
                        icon: "book.fill",
                        color: .blue
                    )
                }
                
                HStack(spacing: 8) {
                    CompactStatCard(
                        title: "history.stats.expired".localized,
                        value: "\(stats.totalExpirationCount)",
                        icon: "trash.fill",
                        color: .red
                    )
                    
                    CompactStatCard(
                        title: "history.stats.adjustments".localized,
                        value: "\(stats.totalAdjustmentCount)",
                        icon: "arrow.up.arrow.down",
                        color: .orange
                    )
                }
            }
        }
    }
    
    // MARK: - Records List Section
    
    private var recordsListSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("history.recent.title".localized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !filteredRecords.isEmpty {
                    Text("\(filteredRecords.count) 条记录")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                // 加载状态
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("history.loading".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 40)
            } else if filteredRecords.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("history.empty.title".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("history.empty.message".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedRecords, id: \.date) { group in
                        DateGroupRow(date: group.date, records: group.records)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "history.today".localized
        } else if calendar.isDateInYesterday(date) {
            return "history.yesterday".localized
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return DateFormatter.monthDay.string(from: date)
        } else {
            return DateFormatter.monthDayYear.string(from: date)
        }
    }
    
    // MARK: - Data Loading
    
    @MainActor
    private func loadStatistics() async {
        isLoading = true
        
        let range = selectedTimeRange.dateRange
        let stats = await HistoryRecordService.shared.getStatistics(
            from: range.start,
            to: range.end,
            in: modelContext
        )
        
        statistics = stats
        isLoading = false
    }
}

// MARK: - Supporting Views

struct CompactStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .glassedBackground(shape: RoundedRectangle(cornerRadius: 8), interactive: false)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var borderColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.1) 
            : Color.black.opacity(0.05)
    }
}

struct DateGroupRow: View {
    let date: Date
    let records: [FoodHistoryRecord]
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    
    var eventTypes: Set<FoodHistoryRecord.RecordType> {
        Set(records.map { $0.type })
    }
    
    var sortedEventTypes: [FoodHistoryRecord.RecordType] {
        // 按逻辑顺序排列事件类型
        let typeOrder: [FoodHistoryRecord.RecordType] = [.purchase, .consumption, .adjustment, .expiration, .recipeTrial]
        return typeOrder.filter { eventTypes.contains($0) }
    }
    
    var sortedRecords: [FoodHistoryRecord] {
        // 按类型顺序排列记录，同一类型内按时间降序排列
        let typeOrder: [FoodHistoryRecord.RecordType] = [.purchase, .consumption, .adjustment, .expiration, .recipeTrial]
        return records.sorted { first, second in
            let firstIndex = typeOrder.firstIndex(of: first.type) ?? typeOrder.count
            let secondIndex = typeOrder.firstIndex(of: second.type) ?? typeOrder.count
            
            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }
            // 同一类型内按时间降序排列
            return first.date > second.date
        }
    }
    
    var hasRecipeRecords: Bool {
        records.contains { $0.type == .consumption && $0.recipeName != nil }
    }
    
    
    var isRecipeGroup: Bool {
        // 检查是否所有记录都有recipeName且类型为consumption
        return !records.isEmpty && records.allSatisfy { $0.type == .consumption && $0.recipeName != nil }
    }
    
    var displayTitle: String {
        if isRecipeGroup, let recipeName = records.first?.recipeName {
            return recipeName
        } else {
            return formatDateHeader(date)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 标题显示（日期或菜谱名）
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if isRecipeGroup {
                            Text("\(records.count) 次制作")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // 事件类型标记
                        HStack(spacing: 6) {
                            ForEach(sortedEventTypes, id: \.self) { type in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(type.color)
                                        .frame(width: 6, height: 6)
                                    
                                    Text(type.displayName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(type.color)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(type.color.opacity(0.15))
                                )
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 记录数量和展开箭头
                    HStack(spacing: 8) {
                        Text("\(records.count) 条记录")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(sortedRecords) { record in
                        HistoryRecordRow(record: record)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassedBackground(shape: RoundedRectangle(cornerRadius: 12), interactive: false)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var borderColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.15) 
            : Color.black.opacity(0.1)
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return DateFormatter.monthDay.string(from: date)
        } else {
            return DateFormatter.monthDayYear.string(from: date)
        }
    }
}

struct HistoryRecordRow: View {
    let record: FoodHistoryRecord
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(record.type.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: record.type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(record.type.color)
            }
            
            // 记录信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(record.itemName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(record.formattedQuantity)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(record.date, format: .dateTime.hour().minute())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if let recipeName = record.recipeName {
                    let recipeText = switch record.type {
                    case .consumption:
                        "history.consumption.recipe".localized.replacingOccurrences(of: "{recipe}", with: recipeName)
                    default:
                        recipeName
                    }
                    
                    Text(recipeText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    static let monthDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

#Preview {
    HistoryOverviewView()
        .modelContainer(for: [FoodHistoryRecord.self, FoodItem.self, FoodGroup.self])
}