import Foundation
import Speech
import AVFoundation
import AVFAudio

@MainActor
@Observable
class VoiceInputService {
    var isRecording = false
    var recognizedText = ""
    var finalRecognizedText: String? = nil
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var audioLevel: Float = 0.0
    var recognitionConfidence: Float = 0.0
    
    private var recognitionStartTime: Date?
    private var lastPartialResult: String = ""
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var hasShownSystemErrorWarning = false
    
    // 识别配置
    private let confidenceThreshold: Float = 0.7 // 置信度阈值，用于日志和监控
    
    init() {
        // Prevent crash in Xcode Previews where speech services are unavailable
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return
        }
        
        // Check if we're running in iOS Simulator
        #if targetEnvironment(simulator)
        // On simulator, speech recognition might not be fully supported
        print("Running in iOS Simulator - Speech recognition may be limited")
        #endif
        
        // 支持中英文识别 - 添加安全检查
        guard SFSpeechRecognizer.authorizationStatus() != .denied else {
            print("Speech recognition is denied")
            return
        }
        
        // 根据用户语言偏好选择语音识别器
        setupSpeechRecognizer()
        
        // 检查语音识别器是否可用
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        requestSpeechAuthorization()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: .languageDidChange,
            object: nil
        )
    }
    
    deinit {
        // Remove observer immediately in deinit (this is safe)
        NotificationCenter.default.removeObserver(self)
        
        // Schedule cleanup without capturing self
        Task.detached { @MainActor in
            // The instance may be deallocated by now, but that's fine
            // We're just ensuring resources are cleaned up
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("[VoiceInputService] Failed to deactivate audio session in cleanup: \(error)")
            }
        }
    }
    
    @objc private func languageDidChange() {
        print("[VoiceInputService] Language changed, updating speech recognizer")
        updateLanguage()
    }
    
    private func setupSpeechRecognizer() {
        let currentLanguage = LocalizationManager.shared.selectedLanguage
        let localeIdentifier: String
        
        switch currentLanguage {
        case "zh-Hans":
            localeIdentifier = "zh-CN"
        case "en":
            localeIdentifier = "en-US"
        default:
            localeIdentifier = "en-US"
        }
        
        print("[VoiceInputService] Setting up speech recognizer for locale: \(localeIdentifier)")
        
        // 优先使用选定的语言，回退到英语
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) ?? 
                          SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        if let recognizer = speechRecognizer {
            print("[VoiceInputService] Speech recognizer setup successful for locale: \(recognizer.locale.identifier)")
        } else {
            print("[VoiceInputService] Failed to setup speech recognizer")
        }
    }
    
    func updateLanguage() {
        setupSpeechRecognizer()
    }
    
    private func getContextualStrings() -> [String] {
        let currentLanguage = LocalizationManager.shared.selectedLanguage
        
        switch currentLanguage {
        case "zh-Hans":
            return buildChineseContextualStrings()
        case "en":
            return buildEnglishContextualStrings()
        default:
            return buildEnglishContextualStrings()
        }
    }
    
    private func buildChineseContextualStrings() -> [String] {
        return [
            // 数字和量词组合 - 高优先级
            "一磅", "二磅", "三磅", "四磅", "五磅", "两磅", "半磅",
            "一公斤", "二公斤", "三公斤", "半公斤", "两公斤",
            "一斤", "二斤", "三斤", "四斤", "五斤", "半斤", "两斤",
            "一两", "二两", "三两", "四两", "五两", "半两", "两两",
            "一斤半", "二斤半", "三斤半", "一斤二两", "二斤三两", "三斤四两",
            "五百克", "一千克", "二百克", "三百克", "四百克",
            "一升", "半升", "两升", "一毫升", "五百毫升",
            "一个", "两个", "三个", "四个", "五个", "六个", "七个", "八个", "九个", "十个",
            "一只", "两只", "三只", "四只", "五只", "一条", "两条", "三条",
            "一根", "两根", "三根", "一片", "两片", "三片", "一块", "两块", "三块",
            "一盒", "两盒", "三盒", "一瓶", "两瓶", "三瓶",
            "一袋", "两袋", "三袋", "一包", "两包", "三包",
            "一打", "两打", "三打", "半打", "1打", "2打", "3打",
            
            // 更多数字单位组合 - 专门针对常用中文计量
            "一颗", "两颗", "三颗", "一粒", "两粒", "三粒",
            "一头", "两头", "三头", "一朵", "两朵", "三朵",
            "一串", "两串", "三串", "一把", "两把", "三把",
            "一束", "两束", "三束", "一对", "两对", "三对",
            "一双", "两双", "三双", "一副", "两副", "三副",
            "一听", "两听", "三听", "一桶", "两桶", "三桶",
            "一缸", "两缸", "三缸", "一坛", "两坛", "三坛",
            "一壶", "两壶", "三壶", "一杯", "两杯", "三杯",
            "一碗", "两碗", "三碗", "一盘", "两盘", "三盘",
            
            // 常见食物名称
            "牛肉", "猪肉", "鸡肉", "鸭肉", "羊肉", "鱼肉", "虾", "蟹",
            "牛奶", "酸奶", "奶酪", "芝士", "黄油", "鸡蛋", "鸭蛋",
            "苹果", "香蕉", "橙子", "柠檬", "西瓜", "葡萄", "草莓", "梨", "桃子", "芒果", "菠萝", "凤梨", "猕猴桃",
            "白菜", "菠菜", "生菜", "韭菜", "芹菜", "萝卜", "胡萝卜", "土豆", "洋葱", "大蒜", "生姜",
            "西红柿", "番茄", "黄瓜", "茄子", "青椒", "红椒", "辣椒", "玉米", "豆角", "蘑菇",
            "大米", "面条", "面包", "馒头", "包子", "饺子", "面粉",
            
            // 单位词 - 扩展版本
            "磅", "公斤", "千克", "斤", "两", "克", "升", "毫升", 
            "个", "只", "条", "根", "片", "块", "颗", "粒", "滴", "张", "本", "份",
            "瓶", "罐", "盒", "袋", "包", "听", "桶", "缸", "坛", "壶", "杯", "碗",
            "件", "棒", "支", "枝", "打", "对", "双", "副", "串", "把", "束", "朵", "头",
            
            // 数字
            "一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "两", "半",
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "20", "50", "100", "200", "500", "1000",
            
            // 修饰词
            "新鲜", "有机", "冷冻", "罐装", "今天", "昨天", "明天", "刚买", "买了"
        ]
    }
    
    private func buildEnglishContextualStrings() -> [String] {
        return [
            // Number and unit combinations - high priority
            "one pound", "two pounds", "three pounds", "four pounds", "five pounds", "half pound",
            "one kilogram", "two kilograms", "three kilograms", "half kilogram",
            "one liter", "two liters", "half liter", "five hundred milliliters",
            "one ounce", "two ounces", "three ounces", "four ounces", "eight ounces",
            "one cup", "two cups", "three cups", "half cup",
            "one tablespoon", "two tablespoons", "one teaspoon", "two teaspoons",
            "one gram", "two grams", "fifty grams", "hundred grams", "five hundred grams",
            
            // Common food names - 增强肉类词汇
            "beef", "ground beef", "beef steak", "beef roast", "beef brisket", "beef ribs",
            "pork", "ground pork", "pork chop", "pork tenderloin", "pork shoulder",
            "chicken", "chicken breast", "chicken thigh", "chicken wings", "whole chicken",
            "duck", "lamb", "turkey", "fish", "salmon", "tuna", "cod", "shrimp", "crab",
            "meat", "red meat", "white meat", "lean meat",
            "milk", "yogurt", "cheese", "butter", "eggs", "duck eggs",
            "apple", "banana", "orange", "lemon", "watermelon", "grapes", "strawberry", "pear", "peach", "mango", "pineapple", "kiwi", "avocado",
            "cabbage", "spinach", "lettuce", "celery", "radish", "carrot", "potato", "onion", "garlic", "ginger",
            "tomato", "tomatoes", "cherry tomato", "cucumber", "eggplant", "pepper", "chili", "corn", "mushrooms",
            "rice", "noodles", "bread", "pasta", "flour",
            
            // Units
            "pounds", "pound", "lbs", "lb", "kilogram", "kilograms", "kg", "gram", "grams", "g",
            "liter", "liters", "L", "milliliter", "milliliters", "mL", "ml",
            "ounce", "ounces", "oz", "cup", "cups", "tablespoon", "tablespoons", "tbsp",
            "teaspoon", "teaspoons", "tsp", "piece", "pieces", "item", "items",
            "bottle", "bottles", "can", "cans", "box", "boxes", "bag", "bags", "pack", "packs",
            
            // Numbers
            "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "twenty", "fifty", "hundred", "thousand", "half", "quarter",
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "20", "50", "100", "200", "500", "1000",
            
            // Modifiers
            "fresh", "organic", "frozen", "canned", "today", "yesterday", "tomorrow", "bought", "got"
        ]
    }
    
    // MARK: - Intelligent Text Correction
    
    private func applyIntelligentCorrections(to text: String) async -> String {
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return text }
            let currentLanguage = LocalizationManager.shared.selectedLanguage
            
            if currentLanguage == "zh-Hans" {
                return self.applyChineseCorrections(to: text)
            } else {
                return self.applyEnglishCorrections(to: text)
            }
        }.value
    }
    
    private func applyFinalCorrections(to text: String) async -> String {
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return text }
            let currentLanguage = LocalizationManager.shared.selectedLanguage
            
            if currentLanguage == "zh-Hans" {
                return self.applyFinalChineseCorrections(to: text)
            } else {
                return self.applyFinalEnglishCorrections(to: text)
            }
        }.value
    }
    
    nonisolated private func applyChineseCorrections(to text: String) -> String {
        var correctedText = text
        
        // 常见的中文语音识别错误修正
        let corrections: [String: String] = [
            // 单位修正
            "凉拌": "两磅",
            "亮版": "两磅", 
            "亮班": "两磅",
            "2棒": "2磅",
            "三棒": "三磅",
            "四棒": "四磅",
            "五棒": "五磅",
            "1棒": "1磅",
            "两棒": "两磅",
            "半棒": "半磅",
            
            // 打(dozen)单位修正
            "沓": "打",
            "踏": "打",
            "塌": "打",
            "达": "打",
            "搭": "打",
            "大": "打",
            "1沓": "1打",
            "2沓": "2打",
            "三沓": "三打",
            "一沓": "一打",
            "两沓": "两打",
            "半沓": "半打",
            
            // 数字修正
            "2磅": "两磅",
            "3磅": "三磅", 
            "4磅": "四磅",
            "5磅": "五磅",
            "1磅": "一磅",
            
            // 食物名称修正
            "流氓": "牛肉",
            "流忙": "牛肉",
            "牛乳": "牛肉",
            "猪肉丝": "猪肉",
            "鸡肉丝": "鸡肉",
            
            // 保留完整的购买相关短语 - 不要删除它们
            "我今天买了": "我今天买了",
            "今天买了": "今天买了",
            "我买了": "我买了",
            "刚买了": "刚买了",
            "刚刚买了": "刚刚买了"
        ]
        
        for (wrong, correct) in corrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        // 清理多余的空格
        correctedText = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        correctedText = correctedText.replacingOccurrences(of: "  ", with: " ")
        
        return correctedText
    }
    
    nonisolated private func applyEnglishCorrections(to text: String) -> String {
        var correctedText = text.lowercased()
        
        // 常见的英文语音识别错误修正
        let corrections: [String: String] = [
            // 单位修正
            "bounce": "ounce",
            "bounds": "pounds", 
            "ponds": "pounds",
            "pounds": "pounds", // 确保正确
            "2 bounce": "2 ounce",
            "two bounce": "two ounce",
            "to pounds": "two pounds",
            "too pounds": "two pounds",
            "tree pounds": "three pounds",
            "for pounds": "four pounds",
            "five bounce": "five ounce",
            
            // 食物名称修正 - 增强版
            "beat": "beef",
            "beef": "beef", // 确保beef保持正确
            "be": "beef", // 常见误识别
            "bee": "beef", // 常见误识别
            "leaf": "beef", // 可能的误识别
            "deep": "beef", // 可能的误识别
            "keep": "beef", // 可能的误识别
            "cheap": "beef", // 可能的误识别
            "sleep": "beef", // 可能的误识别
            "sheep": "beef", // 动物相关可能混淆
            "tomato beat": "tomato beef", // 组合修正
            "tomato be": "tomato beef", // 组合修正
            "tomato bee": "tomato beef", // 组合修正
            "potato beat": "potato beef", // 组合修正
            "potato be": "potato beef", // 组合修正
            "potato bee": "potato beef", // 组合修正
            "pork meet": "pork meat",
            "chicken meet": "chicken meat",
            "meat": "meat", // 确保meat保持正确
            "meet": "meat", // 常见误识别
            "mete": "meat", // 可能误识别
            "meta": "meat", // 可能误识别
            
            // 其他常见食物错误纠正
            "tomato": "tomato", // 确保tomato保持正确
            "potato": "potato", // 确保potato保持正确
            "carrot": "carrot", // 确保carrot保持正确
            "garret": "carrot", // 可能误识别
            "garrett": "carrot", // 可能误识别
            "onion": "onion", // 确保onion保持正确
            "opinion": "onion", // 可能误识别
            "union": "onion", // 可能误识别
            
            // 保留完整的购买相关短语 - 不要删除它们
            "i bought": "i bought",
            "today i bought": "today i bought", 
            "i got": "i got",
            "just bought": "just bought",
            "purchased": "purchased"
        ]
        
        for (wrong, correct) in corrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        // 清理多余的空格
        correctedText = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        correctedText = correctedText.replacingOccurrences(of: "  ", with: " ")
        
        return correctedText
    }
    
    nonisolated private func applyFinalChineseCorrections(to text: String) -> String {
        var finalText = text
        
        // 最终修正，更激进的替换
        let finalCorrections: [String: String] = [
            // 更复杂的模式匹配和修正
            "凉拌牛肉": "两磅牛肉",
            "亮版牛肉": "两磅牛肉",
            "亮班牛肉": "两磅牛肉",
            "2棒牛肉": "2磅牛肉",
            "三棒牛肉": "三磅牛肉",
            "四棒牛肉": "四磅牛肉",
            "五棒牛肉": "五磅牛肉",
            "1棒牛肉": "1磅牛肉",
            "两棒牛肉": "两磅牛肉",
            "半棒牛肉": "半磅牛肉",
            
            // 打(dozen)单位最终修正
            "一沓鸡蛋": "一打鸡蛋",
            "两沓鸡蛋": "两打鸡蛋",
            "三沓鸡蛋": "三打鸡蛋",
            "1沓鸡蛋": "1打鸡蛋",
            "2沓鸡蛋": "2打鸡蛋",
            "半沓鸡蛋": "半打鸡蛋",
            "一踏鸡蛋": "一打鸡蛋",
            "两踏鸡蛋": "两打鸡蛋",
            "一塌鸡蛋": "一打鸡蛋",
            "两塌鸡蛋": "两打鸡蛋",
            "一达鸡蛋": "一打鸡蛋",
            "两达鸡蛋": "两打鸡蛋",
            
            // 增强的食物名称纠错
            "流氓肉": "牛肉",
            "流忙肉": "牛肉", 
            "牛乳肉": "牛肉",
            "租肉": "猪肉",
            "竹肉": "猪肉",
            "鸡内": "鸡肉",
            "基内": "鸡肉",
            "鸭内": "鸭肉",
            "压内": "鸭肉",
            
            // 常见蔬菜纠错
            "白才": "白菜",
            "包才": "白菜",
            "拨才": "白菜",
            "胡罗卜": "胡萝卜",
            "胡箩卜": "胡萝卜",
            "土豆子": "土豆",
            "洋葱头": "洋葱",
            
            // 常见水果纠错
            "苹果子": "苹果",
            "平果": "苹果",
            "香蕉子": "香蕉",
            "橘子": "橙子",
            "桔子": "橙子"
        ]
        
        for (wrong, correct) in finalCorrections {
            finalText = finalText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return finalText
    }
    
    nonisolated private func applyFinalEnglishCorrections(to text: String) -> String {
        var finalText = text
        
        // 最终修正，更激进的替换
        let finalCorrections: [String: String] = [
            // 更复杂的模式匹配和修正
            "2 bounce beef": "2 ounce beef",
            "two bounce beef": "two ounce beef",
            "to pounds beef": "two pounds beef",
            "too pounds beef": "two pounds beef",
            "tree pounds beef": "three pounds beef",
            "for pounds beef": "four pounds beef",
            
            // 针对特定上下文的beef纠正
            "1000g beat": "1000g beef",
            "1000 gram beat": "1000 gram beef",
            "2 pounds beat": "2 pounds beef",
            "5 pounds beat": "5 pounds beef",
            "500g beat": "500g beef",
            "1000g be": "1000g beef",
            "1000g bee": "1000g beef",
            "2 pounds be": "2 pounds beef",
            "2 pounds bee": "2 pounds beef",
            "500g be": "500g beef",
            "500g bee": "500g beef"
        ]
        
        for (wrong, correct) in finalCorrections {
            finalText = finalText.replacingOccurrences(of: wrong, with: correct)
        }
        
        return finalText
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                self?.authorizationStatus = authStatus
            }
        }
    }
    
    func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func startRecording() async throws {
        // 首先检查是否在预览环境
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            throw VoiceInputError.speechRecognitionNotAvailable
        }
        
        // 停止之前的任务
        resetTask()
        
        do {
            // 检查语音识别器是否存在和可用
            guard let speechRecognizer = speechRecognizer else {
                throw VoiceInputError.speechRecognitionNotAvailable
            }
            
            guard speechRecognizer.isAvailable else {
                throw VoiceInputError.speechRecognitionNotAvailable
            }
            
            // 检查权限
            guard authorizationStatus == .authorized else {
                throw VoiceInputError.speechRecognitionNotAuthorized
            }
            
            guard await requestMicrophoneAccess() else {
                throw VoiceInputError.microphoneNotAuthorized
            }
            
            // 设置音频会话 - 更保守的配置
            let audioSession = AVAudioSession.sharedInstance()
            
            guard audioSession.isInputAvailable else {
                throw VoiceInputError.audioInputUnavailable
            }
            
            // 优化音频会话配置以提高识别准确度
            do {
                // 先尝试停用当前会话
                try audioSession.setActive(false)
                
                // 设置高质量录音模式
                try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
                
                // 设置高质量采样率
                try audioSession.setPreferredSampleRate(44100.0)
                
                // 设置IO缓冲持续时间以减少延迟和噪音
                try audioSession.setPreferredIOBufferDuration(0.005)
                
                // 激活会话
                try audioSession.setActive(true)
                
                print("[VoiceInputService] Audio session optimized: sampleRate=\(audioSession.sampleRate), bufferDuration=\(audioSession.ioBufferDuration)")
            } catch {
                print("[VoiceInputService] Advanced audio session setup failed: \(error)")
                
                // 回退到简单配置
                do {
                    try audioSession.setCategory(.record, options: .duckOthers)
                    try audioSession.setActive(true)
                } catch {
                    // 最后回退
                    try audioSession.setCategory(.record)
                    try audioSession.setActive(true)
                }
            }
            
            // 创建识别请求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                throw VoiceInputError.recognitionRequestFailed
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            // 高级语音识别优化设置 - 使用更稳定的配置
            if #available(iOS 16.0, *) {
                // 暂时禁用强制本地识别，让系统自动选择最佳模式
                // 这可以避免频繁的音频会话重启导致的系统错误
                recognitionRequest.requiresOnDeviceRecognition = false
                recognitionRequest.addsPunctuation = false // 禁用标点符号添加，避免干扰食物识别
            }
            
            // 设置任务提示以获得更好的食物相关识别
            if #available(iOS 13.0, *) {
                recognitionRequest.taskHint = .dictation // 使用听写模式而不是搜索模式
                recognitionRequest.contextualStrings = getContextualStrings()
            }
            
            // 设置检测静音的参数
            if #available(iOS 17.0, *) {
                recognitionRequest.shouldReportPartialResults = true
            }
            
            // 创建音频输入节点
            let inputNode = audioEngine.inputNode
            
            // 创建识别任务
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    var isFinal = false
                    if let result = result {
                        let rawText = result.bestTranscription.formattedString
                        let confidence = self?.calculateConfidence(from: result) ?? 0.0
                        
                        // 更新置信度
                        self?.recognitionConfidence = confidence
                        
                        // Always display the raw recognized text to show complete sentences
                        self?.recognizedText = rawText
                        
                        // Apply corrections asynchronously
                        Task {
                            let correctedText = await self?.applyIntelligentCorrections(to: rawText) ?? rawText
                            
                            // Only update if text actually changed to avoid unnecessary processing
                            if correctedText != self?.lastPartialResult {
                                self?.lastPartialResult = correctedText
                                self?.resetSilenceTimer()
                            }
                        }
                        
                        isFinal = result.isFinal
                        
                        if isFinal {
                            // 检查置信度并决定是否需要服务器端识别 - 使用原始文本
                            await self?.handleFinalResult(text: rawText, confidence: confidence)
                        }
                    }
                    
                    
                    if let error = error {
                        // Handle specific speech recognition errors
                        if let speechError = error as NSError? {
                            let errorCode = speechError.code
                            let domain = speechError.domain
                            
                            // Filter out system-level errors that don't affect functionality
                            if domain == "kAFAssistantErrorDomain" && errorCode == 1101 {
                                // This is a system-level error that doesn't affect functionality
                                // Only log once to avoid spam
                                if !(self?.hasShownSystemErrorWarning ?? true) {
                                    print("[VoiceInputService] System speech recognition service issue detected. This is normal and doesn't affect functionality.")
                                    self?.hasShownSystemErrorWarning = true
                                }
                                return // Don't stop recording for this error
                            } else {
                                print("[VoiceInputService] Speech recognition error: \(error)")
                            }
                        }
                        self?.stopRecording()
                    } else if isFinal {
                        self?.stopRecording()
                    }
                }
            }
            
            // 配置音频格式 - 添加错误处理
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
                
                // Update audio level inline to avoid private method access in closure
                guard let self = self, let channelData = buffer.floatChannelData else { return }
                
                let channelDataValue = channelData.pointee
                let channelDataValueArray = UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength))
                
                let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
                let avgPower = 20 * log10(rms)
                
                var normalizedLevel = max(0.0, avgPower + 60.0)
                normalizedLevel = min(normalizedLevel, 60.0)
                normalizedLevel = normalizedLevel / 60.0
                
                Task { @MainActor in
                    self.audioLevel = normalizedLevel
                }
            }
            
            // 启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            recognizedText = ""
            finalRecognizedText = nil
            lastPartialResult = ""
            recognitionStartTime = Date()
            resetSilenceTimer()
        } catch {
            resetTask()
            throw error
        }
    }
    
    func stopRecording() {
        if !isRecording { return }
        
        isRecording = false
        silenceTimer?.invalidate()
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        
        // 清理音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceInputService] Failed to deactivate audio session: \(error)")
        }
        
        // If we haven't set finalRecognizedText yet, but have some recognized text, use it
        if finalRecognizedText == nil && !recognizedText.isEmpty {
            finalRecognizedText = recognizedText
        }
    }

    private func resetTask() {
        isRecording = false
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioLevel = 0.0
        recognitionConfidence = 0.0
        finalRecognizedText = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 安全地移除音频tap
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask = nil
        
        // 清理音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceInputService] Failed to deactivate audio session in resetTask: \(error)")
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Increase silence timeout to 4 seconds for better capture of complete sentences
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                if let currentText = self?.recognizedText, !currentText.isEmpty {
                    self?.finalRecognizedText = currentText
                }
                self?.stopRecording()
            }
        }
    }
    
    // MARK: - 混合识别策略方法
    
    // 计算识别置信度
    private func calculateConfidence(from result: SFSpeechRecognitionResult) -> Float {
        let transcription = result.bestTranscription
        
        // 计算平均置信度
        guard !transcription.segments.isEmpty else { return 0.0 }
        
        let totalConfidence = transcription.segments.reduce(0.0) { sum, segment in
            return sum + segment.confidence
        }
        
        let averageConfidence = totalConfidence / Float(transcription.segments.count)
        
        print("[VoiceInputService] Recognition confidence: \(averageConfidence) for text: '\(transcription.formattedString)'")
        return averageConfidence
    }
    
    // 处理最终结果，应用智能纠错
    private func handleFinalResult(text: String, confidence: Float) async {
        print("[VoiceInputService] Handling final result - confidence: \(confidence)")
        print("[VoiceInputService] Raw recognized text: '\(text)'")
        
        // 使用原始识别文本，但应用智能纠错用于解析
        finalRecognizedText = text
        
        if confidence < confidenceThreshold {
            print("[VoiceInputService] Low confidence (\(confidence)), displaying complete sentence: '\(text)'")
        } else {
            print("[VoiceInputService] High confidence result (\(confidence)): '\(text)'")
        }
    }
}

enum VoiceInputError: Error, LocalizedError {
    case speechRecognitionNotAuthorized
    case microphoneNotAuthorized
    case recognitionRequestFailed
    case audioInputUnavailable
    case speechRecognitionNotAvailable
    case audioSessionFailed
    case audioEngineFailed
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionNotAuthorized:
            return "语音识别未授权"
        case .microphoneNotAuthorized:
            return "麦克风未授权"
        case .recognitionRequestFailed:
            return "语音识别请求失败"
        case .audioInputUnavailable:
            return "音频输入设备不可用"
        case .speechRecognitionNotAvailable:
            return "语音识别服务不可用"
        case .audioSessionFailed:
            return "音频会话设置失败"
        case .audioEngineFailed:
            return "音频引擎启动失败"
        }
    }
}
