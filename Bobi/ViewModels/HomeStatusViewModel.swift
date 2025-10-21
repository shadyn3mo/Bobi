import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Home Status ViewModel

/// 主页状态视图模型
@MainActor
class HomeStatusViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var homeStatusData: HomeStatusData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var greeting: String {
        homeStatusData?.greeting ?? "home.greeting.default".localized
    }
    
    var weatherInfo: WeatherInfo? {
        homeStatusData?.weatherInfo
    }
    
    var hasWeatherInfo: Bool {
        weatherInfo != nil
    }
    
    var dailyCalorieNeeds: Double {
        homeStatusData?.dailyCalorieNeeds ?? 0
    }
    
    // 移除库存相关属性，现在主页不再依赖库存信息
    
    var mealSuggestion: MealSuggestion? {
        homeStatusData?.mealSuggestion
    }
    
    // 移除采购单相关属性，简化主页功能
    
    var lifeTips: [LifeTip] {
        homeStatusData?.lifeTips ?? []
    }
    
    var lastUpdated: Date? {
        homeStatusData?.lastUpdated
    }
    
    // 心情状态相关属性
    var currentMood: UserMood? {
        homeStatusService.currentMood
    }
    
    var shouldPromptMoodSelection: Bool {
        homeStatusService.shouldPromptMoodSelection
    }
    
    var lastMoodUpdateTime: Date? {
        homeStatusService.lastMoodUpdateTime
    }
    
    @Published var isMealSuggestionLoading: Bool = false
    
    // MARK: - Private Properties
    private let homeStatusService = HomeStatusService.shared
    private var modelContext: ModelContext?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupAutoRefresh()
        setupNotificationListeners()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// 设置模型上下文
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        homeStatusService.setModelContext(context)
    }
    
    /// 加载初始数据（异步，不阻塞UI）
    func loadInitialData() {
        Task {
            await loadData(showLoading: true)
        }
    }
    
    /// 检查心情状态（在应用前台时调用）
    func checkMoodStatus() {
        // 触发心情状态检查，这会更新shouldPromptMoodSelection
        homeStatusService.updateMoodPromptStatus()
    }
    
    /// 刷新数据
    func refreshData() async {
        await loadData(showLoading: false)
    }
    
    /// 手动刷新数据
    func manualRefresh() async {
        // 重置失败状态
        homeStatusService.resetAiGenerationFailedState()
        let _ = await homeStatusService.refreshData()
        await loadData(showLoading: true)
    }
    
    /// 设置用户心情并触发AI内容生成
    func setUserMood(_ mood: UserMood) {
        homeStatusService.setUserMood(mood)
        // 心情变化后异步生成AI内容并刷新数据
        Task {
            // 等待AI内容生成完成
            await homeStatusService.generateAiContent()
            // 然后刷新数据
            await refreshData()
        }
    }
    
    /// 检查AI内容是否可用
    func hasAiContentAvailable() -> Bool {
        return homeStatusService.hasAiContentAvailable()
    }
    
    /// 检查AI生成是否失败
    var isAiGenerationFailed: Bool {
        return homeStatusService.isAiGenerationFailed()
    }
    
    /// 检查是否达到每日AI限额
    var isDailyLimitReached: Bool {
        return homeStatusService.isDailyLimitReached()
    }
    
    /// 手动触发心情提醒
    func triggerMoodPrompt() {
        homeStatusService.triggerMoodPrompt()
    }
    
    /// 获取心情剩余有效时间（小时）
    func getMoodRemainingHours() -> Int {
        return homeStatusService.getMoodRemainingHours()
    }
    
    // MARK: - Action Methods
    
    /// 获取格式化的卡路里需求文本
    func getFormattedCalorieNeeds() -> String {
        if dailyCalorieNeeds > 0 {
            return String(format: "daily.calorie.needs".localized, Int(dailyCalorieNeeds))
        } else {
            return "daily.calorie.needs.unknown".localized
        }
    }
    
    // 移除了库存和采购单相关的工具方法，因为主页不再依赖这些功能
    
    // MARK: - Private Methods
    
    private func loadData(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }
        
        let statusData = await homeStatusService.generateHomeStatusData()
        await MainActor.run {
            self.homeStatusData = statusData
            self.errorMessage = nil
            self.isLoading = false
        }
    }
    
    private func setupAutoRefresh() {
        // 设置定时器，每30分钟自动刷新一次数据（配合1小时天气缓存）
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
    }
    
    private func setupNotificationListeners() {
        // 监听AI内容更新通知
        NotificationCenter.default.addObserver(
            forName: .homeStatusDataUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
        
        // 监听加载状态变化
        homeStatusService.$isMealSuggestionLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isMealSuggestionLoading = isLoading
            }
            .store(in: &cancellables)
    }
}

// MARK: - Extensions for Data Formatting

extension HomeStatusViewModel {
    /// 获取最后更新时间的友好显示
    func getLastUpdatedText() -> String {
        guard let lastUpdated = lastUpdated else {
            return "last.updated.unknown".localized
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return String(format: "last.updated".localized, formatter.localizedString(for: lastUpdated, relativeTo: Date()))
    }
    
    /// 获取天气显示文本
    func getWeatherDisplayText() -> String {
        guard let weather = weatherInfo else {
            return "weather.unknown".localized
        }
        
        return String(format: "weather.display".localized, weather.description, String(format: "%.0f", weather.temperature))
    }
    
    // 移除了库存摘要方法，因为主页不再显示库存信息
    
    /// 获取生活小贴士摘要
    func getLifeTipsSummary() -> String {
        let relevantTips = lifeTips.filter { $0.isRelevant }
        if relevantTips.isEmpty {
            return "life.tips.empty".localized
        } else {
            return relevantTips.first?.message ?? "life.tips.default".localized
        }
    }
}

// MARK: - Mock Data for Preview

extension HomeStatusViewModel {
    /// 创建用于预览的模拟数据
    static func mock() -> HomeStatusViewModel {
        let viewModel = HomeStatusViewModel()
        viewModel.homeStatusData = HomeStatusData(
            greeting: "weekday.morning.greeting".localized,
            weatherInfo: WeatherInfo(
                temperature: 22.0,
                condition: .cloudy,
                description: "多云",
                iconName: "cloud.fill"
            ),
            dailyCalorieNeeds: 2400,
            mealSuggestion: MealSuggestion.mockSuggestions.first,
            lifeTips: [
                LifeTip(
                    icon: "lightbulb.fill",
                    message: "今天是工作日，建议简单快手菜",
                    type: .timeBasedSuggestion
                ),
                LifeTip(
                    icon: "heart.fill",
                    message: "本周已尝试3道新菜，多样性很好！",
                    type: .encouragement
                )
            ]
        )
        return viewModel
    }
}