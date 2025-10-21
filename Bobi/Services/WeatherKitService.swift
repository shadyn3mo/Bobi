import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import Network

/// 基于Gemini CLI研究和Apple最佳实践的健壮WeatherKit服务
/// 
/// 特点：
/// 1. 正确的async/await桥接，避免continuation泄漏
/// 2. 统一的错误处理和超时机制
/// 3. 资源管理优化（获取位置后立即停止更新）
/// 4. 线程安全的状态管理
/// 5. 成本优化缓存策略（1小时在线缓存，4小时离线缓存）
@MainActor
final class WeatherKitService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = WeatherKitService()
    
    // MARK: - Published Properties
    @Published var currentWeather: WeatherInfo?
    @Published var isLoading = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Custom Error Types
    enum WeatherError: Error, LocalizedError {
        case invalidState
        case locationPermissionDenied
        case locationFetchFailed(Error)
        case weatherFetchFailed(Error)
        case timedOut
        case authenticationFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidState:
                return "weather.error.invalid_state".localized
            case .locationPermissionDenied:
                return "location.permission.required".localized
            case .locationFetchFailed(let error):
                return "location.error".localized + ": \(error.localizedDescription)"
            case .weatherFetchFailed(let error):
                return "weather.error.general".localized + ": \(error.localizedDescription)"
            case .timedOut:
                return "weather.error.timeout".localized
            case .authenticationFailed:
                return "weather.error.authentication".localized
            }
        }
    }
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService.shared
    private var lastWeatherUpdate: Date?
    private let cacheInterval: TimeInterval = 3600 // 1小时缓存
    private let extendedCacheInterval: TimeInterval = 14400 // 4小时离线缓存
    private var lastLocation: CLLocation?
    private let locationChangeThreshold: Double = 1000 // 1km 位置变化阈值
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkConnected = true
    
    /// Continuation用于桥接delegate回调到async/await
    /// 关键：确保只能同时有一个位置请求
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    /// 防止并发刷新的标志
    private var isRefreshing = false
    
    // MARK: - Initialization
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
        loadCacheFromUserDefaults()
        setupNetworkMonitoring()
    }
    
    // MARK: - Public API
    
    /// 请求位置权限
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Location permission denied or restricted")
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission already granted")
        @unknown default:
            break
        }
    }
    
    /// 获取当前天气（智能缓存）
    func getCurrentWeather() async -> WeatherInfo? {
        // 检查网络状态
        let isOnline = await isNetworkAvailable()
        
        // 检查缓存有效性和位置变化
        if let lastUpdate = lastWeatherUpdate,
           let weather = currentWeather {
            
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            let effectiveCacheInterval = isOnline ? cacheInterval : extendedCacheInterval
            
            // 如果缓存仍然有效，直接返回
            // 位置变化检查将在 refreshWeather() 中进行，避免过度的位置请求
            if timeSinceUpdate < effectiveCacheInterval {
                let ageHours = timeSinceUpdate / 3600
                let ageMinutes = Int(timeSinceUpdate / 60)
                if ageHours >= 1 {
                    print("🌤️ Using cached weather data (age: \(String(format: "%.1f", ageHours))h, online: \(isOnline))")
                } else {
                    print("🌤️ Using cached weather data (age: \(ageMinutes)min, online: \(isOnline))")
                }
                return weather
            }
        }
        
        // 只有在线时才尝试刷新
        if isOnline {
            print("🌤️ Refreshing weather data (cache expired or location changed)")
            await refreshWeather()
        } else {
            print("🌤️ Offline - using extended cache (may be stale)")
        }
        
        return currentWeather
    }
    
    /// 刷新天气数据
    func refreshWeather() async {
        // 防止并发刷新
        guard !isRefreshing else {
            print("🌤️ Weather refresh already in progress, skipping")
            return
        }
        
        isRefreshing = true
        isLoading = true
        
        do {
            // 使用统一的超时机制获取天气
            let (weather, location) = try await fetchWeatherForCurrentLocationWithLocation(timeout: 10.0)
            
            // 检查位置是否发生显著变化
            if let lastLoc = lastLocation {
                let distance = location.distance(from: lastLoc)
                if distance > locationChangeThreshold {
                    print("🌤️ Significant location change detected: \(Int(distance))m")
                } else if distance > 0 {
                    print("🌤️ Minor location change: \(Int(distance))m (threshold: \(Int(locationChangeThreshold))m)")
                }
            }
            
            let weatherInfo = convertToWeatherInfo(weather)
            print("🌤️ WeatherKit API call successful - fetched fresh data")
            
            self.currentWeather = weatherInfo
            self.lastWeatherUpdate = Date()
            self.lastLocation = location
            
            // 保存到持久化缓存
            saveCacheToUserDefaults()
            
        } catch let error as WeatherError {
            await handleWeatherError(error)
        } catch {
            await handleWeatherError(.weatherFetchFailed(error))
        }
        
        isLoading = false
        isRefreshing = false
    }
    
    /// 清除缓存
    func clearCache() {
        currentWeather = nil
        lastWeatherUpdate = nil
        UserDefaults.standard.removeObject(forKey: "cached_weather_data")
        UserDefaults.standard.removeObject(forKey: "cached_weather_timestamp")
        UserDefaults.standard.removeObject(forKey: "cached_weather_lat")
        UserDefaults.standard.removeObject(forKey: "cached_weather_lng")
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Private Core Logic
    
    /// 主要的天气获取方法（基于Gemini最佳实践）
    private func fetchWeatherForCurrentLocation(timeout: TimeInterval = 10.0) async throws -> Weather {
        try await withTimeout(seconds: timeout) {
            let location = try await self.requestLocation()
            let weather = try await self.weatherService.weather(for: location)
            return weather
        }
    }
    
    /// 获取天气和位置信息
    private func fetchWeatherForCurrentLocationWithLocation(timeout: TimeInterval = 10.0) async throws -> (Weather, CLLocation) {
        try await withTimeout(seconds: timeout) {
            let location = try await self.requestLocation()
            let weather = try await self.weatherService.weather(for: location)
            return (weather, location)
        }
    }
    
    /// 通用超时包装器
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // 添加主操作任务
            group.addTask {
                try await operation()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw WeatherError.timedOut
            }
            
            // 等待第一个完成的任务
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// 安全的位置请求（防止continuation泄漏）
    private func requestLocation() async throws -> CLLocation {
        // 防止并发请求
        guard locationContinuation == nil else {
            throw WeatherError.invalidState
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            
            let status = locationManager.authorizationStatus
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                resumeContinuation(throwing: WeatherError.locationPermissionDenied)
            @unknown default:
                resumeContinuation(throwing: WeatherError.invalidState)
            }
        }
    }
    
    /// 安全的continuation恢复（防止重复调用）
    private func resumeContinuation(returning location: CLLocation) {
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }
    
    private func resumeContinuation(throwing error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
    
    /// 转换WeatherKit数据到我们的模型
    private func convertToWeatherInfo(_ weather: Weather) -> WeatherInfo {
        let currentWeather = weather.currentWeather
        let condition = mapWeatherKitCondition(currentWeather.condition)
        
        // 为晴朗天气创建时间感知的描述
        let description = generateTimeAwareDescription(
            condition: condition, 
            isDaylight: currentWeather.isDaylight
        )
        
        return WeatherInfo(
            temperature: currentWeather.temperature.converted(to: .celsius).value,
            condition: condition,
            description: description,
            iconName: mapToSFSymbol(currentWeather.condition, isDaylight: currentWeather.isDaylight),
            location: "location.current".localized,
            humidity: currentWeather.humidity,
            windSpeed: currentWeather.wind.speed.converted(to: .kilometersPerHour).value,
            uvIndex: currentWeather.uvIndex.value
        )
    }
    
    /// 生成时间感知的天气描述
    private func generateTimeAwareDescription(condition: WeatherCondition, isDaylight: Bool) -> String {
        switch condition {
        case .sunny:
            return isDaylight ? "weather.sunny".localized : "weather.clear_night".localized
        case .cloudy:
            // 夜晚的多云天气描述也可以更贴切，但暂时保持原样
            return condition.localizedName
        default:
            return condition.localizedName
        }
    }
    
    /// 映射WeatherKit条件到我们的枚举
    private func mapWeatherKitCondition(_ condition: WeatherKit.WeatherCondition) -> Bobi.WeatherCondition {
        switch condition {
        case .clear, .mostlyClear, .partlyCloudy:
            return .sunny
        case .cloudy, .mostlyCloudy:
            return .cloudy
        case .rain, .drizzle, .heavyRain:
            return .rainy
        case .snow, .sleet, .blizzard:
            return .snowy
        case .freezingRain, .freezingDrizzle:
            return .cold
        case .thunderstorms:
            return .rainy
        case .foggy:
            return .cloudy
        case .breezy, .windy:
            return .windy
        default:
            return .cloudy
        }
    }
    
    /// 映射到SF Symbol图标
    private func mapToSFSymbol(_ condition: WeatherKit.WeatherCondition, isDaylight: Bool) -> String {
        switch condition {
        case .clear:
            return isDaylight ? "sun.max.fill" : "moon.stars.fill"
        case .mostlyClear, .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy:
            return "cloud.fill"
        case .rain, .drizzle:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .sleet:
            return "cloud.sleet.fill"
        case .thunderstorms:
            return "cloud.bolt.rain.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .breezy, .windy:
            return "wind"
        default:
            return "cloud.fill"
        }
    }
    
    /// 统一的错误处理
    private func handleWeatherError(_ error: WeatherError) async {
        print("WeatherKit error: \(error.localizedDescription)")
        
        // 根据错误类型决定是否保留当前天气数据
        switch error {
        case .timedOut, .weatherFetchFailed:
            // 网络或服务错误，保留缓存的天气数据
            break
        case .locationPermissionDenied, .locationFetchFailed:
            // 位置相关错误，清除天气数据
            currentWeather = nil
        case .authenticationFailed:
            // 认证错误，清除数据但记录供调试
            print("WeatherKit authentication failed - check app configuration")
            currentWeather = nil
        case .invalidState:
            // 状态错误，通常是并发问题
            break
        }
    }
    
    // MARK: - Cache Management
    
    /// 网络可用性检查
    private func isNetworkAvailable() async -> Bool {
        return isNetworkConnected
    }
    
    /// 设置网络监控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.isNetworkConnected ?? true
                self?.isNetworkConnected = path.status == .satisfied
                
                // 网络恢复时，刷新天气数据（如果缓存已过期）
                if !wasConnected && self?.isNetworkConnected == true {
                    print("🌐 Network restored, checking if weather data needs refresh")
                    if let lastUpdate = self?.lastWeatherUpdate,
                       Date().timeIntervalSince(lastUpdate) > self?.cacheInterval ?? 3600 {
                        await self?.refreshWeather()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    /// 位置是否发生显著变化
    private func shouldRefreshForLocation(_ newLocation: CLLocation) -> Bool {
        guard let lastLoc = lastLocation else { return true }
        return newLocation.distance(from: lastLoc) > locationChangeThreshold
    }
    
    /// 加载持久化缓存
    private func loadCacheFromUserDefaults() {
        if let weatherData = UserDefaults.standard.data(forKey: "cached_weather_data"),
           let weather = try? JSONDecoder().decode(WeatherInfo.self, from: weatherData),
           let timestamp = UserDefaults.standard.object(forKey: "cached_weather_timestamp") as? Date {
            
            let lat = UserDefaults.standard.double(forKey: "cached_weather_lat")
            let lng = UserDefaults.standard.double(forKey: "cached_weather_lng")
            
            currentWeather = weather
            lastWeatherUpdate = timestamp
            if lat != 0 || lng != 0 {
                lastLocation = CLLocation(latitude: lat, longitude: lng)
            }
            
            print("🌤️ Loaded weather cache from persistent storage")
        }
    }
    
    /// 保存缓存到持久化存储
    private func saveCacheToUserDefaults() {
        if let weatherData = try? JSONEncoder().encode(currentWeather) {
            UserDefaults.standard.set(weatherData, forKey: "cached_weather_data")
            UserDefaults.standard.set(lastWeatherUpdate, forKey: "cached_weather_timestamp")
            if let location = lastLocation {
                UserDefaults.standard.set(location.coordinate.latitude, forKey: "cached_weather_lat")
                UserDefaults.standard.set(location.coordinate.longitude, forKey: "cached_weather_lng")
            }
            print("🌤️ Saved weather cache to persistent storage")
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherKitService: CLLocationManagerDelegate {
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            // 如果权限获得，且有等待的continuation，继续位置请求
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                if locationContinuation != nil {
                    locationManager.requestLocation()
                }
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                resumeContinuation(throwing: WeatherError.locationPermissionDenied)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else {
                print("No location found in didUpdateLocations")
                resumeContinuation(throwing: WeatherError.locationFetchFailed(NSError(domain: "LocationError", code: 1)))
                return
            }
            
            // 立即停止位置更新以节省电量（最佳实践）
            manager.stopUpdatingLocation()
            print("Location obtained: \(location.coordinate)")
            resumeContinuation(returning: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location manager error: \(error.localizedDescription)")
            
            // 检查是否是WeatherKit JWT认证错误
            if error.localizedDescription.contains("WDSJWTAuthenticatorServiceListener") {
                resumeContinuation(throwing: WeatherError.authenticationFailed)
            } else {
                resumeContinuation(throwing: WeatherError.locationFetchFailed(error))
            }
        }
    }
}

// MARK: - WeatherKit Condition Extension

extension WeatherKit.WeatherCondition {
    var localizedDescription: String {
        switch self {
        case .clear:
            return "weather.clear".localized
        case .cloudy:
            return "weather.cloudy".localized
        case .rain:
            return "weather.rainy".localized
        case .snow:
            return "weather.snowy".localized
        case .thunderstorms:
            return "weather.thunderstorms".localized
        case .foggy:
            return "weather.foggy".localized
        case .windy:
            return "weather.windy".localized
        default:
            return description
        }
    }
}