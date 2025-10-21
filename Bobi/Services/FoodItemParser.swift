import Foundation
import NaturalLanguage

struct ParsedFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var quantity: Int
    var unit: String // 存储的单位（用于数据库和编辑）
    var displayUnit: String? // 显示用的单位（用于界面显示）
    var category: FoodCategory
    var purchaseDate: Date
    var estimatedExpirationDate: Date?
    var specificEmoji: String?
    var needsVolumeInput: Bool = false // 是否需要用户输入具体体积
    var recommendedStorageLocation: StorageLocation
    var storageLocation: StorageLocation // 用户选择的存储位置
    var imageData: Data? // 食材图片数据

    var displayIcon: String {
        return specificEmoji ?? category.icon
    }
    
    var effectiveDisplayUnit: String {
        return displayUnit ?? unit
    }
}

class FoodItemParser {
    static let shared = FoodItemParser()
    
    @available(iOS 17.0, *)
    private lazy var localClassifier = LocalFoodClassifier.shared
    
    // A temporary struct to hold synchronously parsed data
    private struct RawFoodComponent {
        var name: String
        var quantity: Double? // 改为Double以支持分数
        var unit: String?
        var displayUnit: String?
    }
    
    private init() {}
    
    // Helper function to determine if space should be added between tokens
    private func shouldAddSpaceBetweenTokens(_ currentName: String, _ newToken: String) -> Bool {
        // If either the current name or new token contains Chinese characters, don't add space
        let chineseRange = "\\p{Script=Han}"
        let chineseRegex = try? NSRegularExpression(pattern: chineseRange)
        
        let currentNameRange = NSRange(location: 0, length: currentName.utf16.count)
        let newTokenRange = NSRange(location: 0, length: newToken.utf16.count)
        
        let currentNameHasChinese = chineseRegex?.firstMatch(in: currentName, options: [], range: currentNameRange) != nil
        let newTokenHasChinese = chineseRegex?.firstMatch(in: newToken, options: [], range: newTokenRange) != nil
        
        // Don't add space if either token contains Chinese characters
        if currentNameHasChinese || newTokenHasChinese {
            return false
        }
        
        // For non-Chinese text, add space as usual
        return true
    }
    
    // Apply intelligent corrections for parsing food items
    private func applyParsingCorrections(to text: String) async -> String {
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return text }
            let currentLanguage = LocalizationManager.shared.selectedLanguage
            
            if currentLanguage == "zh-Hans" {
                return self.applyChineseParsingCorrections(to: text)
            } else {
                return self.applyEnglishParsingCorrections(to: text)
            }
        }.value
    }
    
    nonisolated private func applyChineseParsingCorrections(to text: String) -> String {
        var correctedText = text
        
        // 保护常用时间词汇，避免误纠正
        let protectedTimeWords = ["今天", "昨天", "明天", "今日", "今晚", "今早", "今夜"]
        
        // 保护常见食物名称，避免误纠正
        let protectedFoodWords = [
            // 含"金"的食物
            "金针菇", "金枪鱼", "金桔", "金银花", "金丝瓜", "金玉米", "金瓜", "金钱菇", "金丝枣",
            "金花菜", "金针", "金橘", "金鱼", "金华火腿",
            // 含"生"的食物
            "生菜", "生姜", "花生", "生抽", "生蚝", "生鱼片", "生肉", "生虾", "生粉",
            "生鱼", "生鸡蛋", "生牛肉", "生猪肉", "生鸭", "生煎包", "生煎",
            // 含"大"的食物
            "大蒜", "大葱", "大白菜", "大米", "大麦", "大豆", "大虾", "大闸蟹", "大枣",
            "大头菜", "大料", "大红枣", "大青菜", "大排", "大肠", "大骨", "大饼",
            // 含"亮"的食物
            "亮晶晶", "透亮", "发亮",
            // 含"量"的词汇
            "大量", "少量", "适量", "微量", "定量", "重量", "分量", "容量",
            // 含"凉"的食物
            "凉粉", "凉皮", "凉菜", "凉茶", "凉糕", "凉面", "凉拌菜", "凉拌", "凉瓜",
            // 含"客"的食物
            "客家", "客饭",
            // 乳制品保护 (避免"酸奶"被拆分)
            "酸奶", "牛奶", "奶酪", "奶油", "黄油", "芝士", "炼乳", "豆奶",
            // 其他可能被误纠正的食物
            "近视", "紧张", "良心", "梁子", "声音", "升级", "胜利", "圣诞"
        ]
        
        var protectedMap: [String: String] = [:]
        
        // 临时替换保护词汇
        let allProtectedWords = protectedTimeWords + protectedFoodWords
        for (index, word) in allProtectedWords.enumerated() {
            if correctedText.contains(word) {
                let placeholder = "___PROTECTED_PLACEHOLDER_\(index)___"
                protectedMap[placeholder] = word
                correctedText = correctedText.replacingOccurrences(of: word, with: placeholder)
            }
        }
        
        // 常见的中文语音识别错误修正 - 更保守的版本，只修复明显错误
        let corrections: [String: String] = [
            // 单位修正 - 只修正明显的单位错误
            // "凉拌": "两磅", // 移除，"凉拌"是常见烹饪方式
            "亮版": "两磅", "亮班": "两磅", "两班": "两磅", "凉班": "两磅",
            "1棒": "1磅", "2棒": "2磅", "三棒": "三磅", "四棒": "四磅", "五棒": "五磅", 
            "两棒": "两磅", "半棒": "半磅", "一棒": "一磅",
            // 带数字的"凉"才修正为"两"（磅）
            "1凉": "1两", "2凉": "2两", "三凉": "三两", "四凉": "四两", "五凉": "五两",
            "一凉": "一两", "两凉": "两两", "半凉": "半两",
            
            // 打(dozen)单位修正
            "沓": "打", "踏": "打", "塌": "打", "达": "打", "搭": "打",
            "1沓": "1打", "2沓": "2打", "三沓": "三打", "四沓": "四打", "五沓": "五打",
            "一沓": "一打", "两沓": "两打", "半沓": "半打",
            "1大": "1打", "2大": "2打", "三大": "三打", "四大": "四打", "五大": "五打",
            "一大": "一打", "两大": "两打", "半大": "半打",
            
            // 数字修正
            "2磅": "两磅", "3磅": "三磅", "4磅": "四磅", "5磅": "五磅", "1磅": "一磅",
            "两帮": "两磅", "三帮": "三磅", "四帮": "四磅", "五帮": "五磅",
            
            // 重量单位修正
            "工程": "公斤", "公今": "公斤", "公近": "公斤", "工今": "公斤",
            "千克": "公斤", "前克": "千克", "浅克": "千克",
            "客": "克", "格": "克", "各": "克",
            
            // 斤两单位修正 - 更精确的上下文相关修正
            // "金": "斤", // 移除，避免影响"金针菇"等食物
            // "亮": "两", // 移除，避免影响含"亮"的词汇
            // "量": "两", // 移除，避免影响"大量"等词汇
            "近": "斤", "紧": "斤",
            "良": "两", "梁": "两",
            "斤亮": "斤两", "斤量": "斤两", "斤良": "斤两", "斤凉": "斤两",
            "金两": "斤两", "近两": "斤两", "今两": "斤两",
            
            // 常见斤两组合修正
            "一金二亮": "一斤二两", "二金三亮": "二斤三两", "三金四亮": "三斤四两",
            "半金": "半斤", "半亮": "半两", "半金半亮": "半斤半两",
            "一金半": "一斤半", "二金半": "二斤半", "三金半": "三斤半",
            
            // 单独斤两的修正 - 带数字前缀时才修正
            "一金": "一斤", "二金": "二斤", "三金": "三斤", "四金": "四斤", "五金": "五斤",
            "一亮": "一两", "二亮": "二两", "三亮": "三两", "四亮": "四两", "五亮": "五两",
            "两金": "两斤",
            "一近": "一斤", "二近": "二斤",
            "一良": "一两", "二良": "二两",
            
            // 体积单位修正
            "毫升": "mL", "豪升": "mL", "号升": "mL", "好升": "mL",
            // "生": "升", // 移除，避免影响"生菜"、"生姜"等食物
            "胜": "升", "圣": "升", "声": "升",
            "1生": "1升", "2生": "2升", "三生": "三升", "四生": "四升", "五生": "五升",
            "一生": "一升", "两生": "两升", "半生": "半升",
            // 加仑单位修正
            "嘉伦": "加仑", "佳伦": "加仑", "家伦": "加仑", "贾伦": "加仑",
            "美嘉伦": "美加仑", "美佳伦": "美加仑", "美家伦": "美加仑",
            
            // 常见食材名称修正
            // 肉类
            "流氓": "牛肉", "流忙": "牛肉", "牛乳": "牛肉", "留忙": "牛肉",
            "猪肉丝": "猪肉", "鸡肉丝": "鸡肉", "鸭肉丝": "鸭肉",
            "里几": "里脊", "里脊肉": "里脊", "里记": "里脊",
            "五花": "五花肉", "午花": "五花肉", "无花": "五花肉",
            "鸡翅": "鸡翅", "鸡次": "鸡翅", "鸡刺": "鸡翅",
            "鸡腿": "鸡腿", "吉腿": "鸡腿", "极腿": "鸡腿",
            
            // 蔬菜类
            "西红柿": "西红柿", "西红式": "西红柿", "西红市": "西红柿",
            "番茄": "西红柿", "反茄": "西红柿", "范茄": "西红柿",
            "胡萝卜": "胡萝卜", "胡萝白": "胡萝卜", "湖萝卜": "胡萝卜",
            "白菜": "白菜", "百菜": "白菜", "摆菜": "白菜",
            "青椒": "青椒", "青叫": "青椒", "清椒": "青椒",
            "黄瓜": "黄瓜", "黄挂": "黄瓜", "皇瓜": "黄瓜",
            "茄子": "茄子", "加子": "茄子", "假子": "茄子",
            "豆角": "豆角", "豆脚": "豆角", "逗角": "豆角",
            "芹菜": "芹菜", "秦菜": "芹菜", "琴菜": "芹菜",
            "韭菜": "韭菜", "九菜": "韭菜", "救菜": "韭菜",
            "菠菜": "菠菜", "波菜": "菠菜", "拨菜": "菠菜",
            "生菜": "生菜", "声菜": "生菜", "升菜": "生菜",
            "洋葱": "洋葱", "阳葱": "洋葱", "羊葱": "洋葱",
            "土豆": "土豆", "图豆": "土豆", "突豆": "土豆",
            "红薯": "红薯", "红鼠": "红薯", "虹薯": "红薯",
            "芦笋": "芦笋", "露宿": "芦笋", "路损": "芦笋",
            "羽衣甘蓝": "羽衣甘蓝", "雨衣甘蓝": "羽衣甘蓝",
            "西兰花": "西兰花", "西蓝花": "西兰花",
            
            // 水果类
            "苹果": "苹果", "平果": "苹果", "萍果": "苹果",
            "香蕉": "香蕉", "想蕉": "香蕉", "向蕉": "香蕉",
            "橙子": "橙子", "成子": "橙子", "承子": "橙子",
            "柠檬": "柠檬", "宁檬": "柠檬", "凝檬": "柠檬",
            "葡萄": "葡萄", "铺萄": "葡萄", "扑萄": "葡萄",
            "草莓": "草莓", "草没": "草莓", "草美": "草莓",
            "西瓜": "西瓜", "西挂": "西瓜", "席瓜": "西瓜",
            "猕猴桃": "猕猴桃", "弥猴桃": "猕猴桃", "迷猴桃": "猕猴桃",
            "火龙果": "火龙果", "火龙国": "火龙果", "伙龙果": "火龙果",
            "蓝莓": "蓝莓", "兰梅": "蓝莓",
            "牛油果": "牛油果", "你有过": "牛油果",
            
            // 乳制品
            "牛奶": "牛奶", "留奶": "牛奶", "牛来": "牛奶",
            "酸奶": "酸奶", "酸来": "酸奶", "算奶": "酸奶",

            "奶酪": "奶酪", "来酪": "奶酪", "奶老": "奶酪",
            // 注意：单独的"奶"字映射移到了后面的特殊处理中
            "鸡蛋": "鸡蛋", "吉蛋": "鸡蛋", "机蛋": "鸡蛋",
            
            // 主食类
            "大米": "大米", "打米": "大米", "大迷": "大米",
            "面条": "面条", "面跳": "面条", "面调": "面条",
            "面包": "面包", "面抱": "面包", "面报": "面包",
            "馒头": "馒头", "蛮头": "馒头", "满头": "馒头",
            "包子": "包子", "包紫": "包子", "宝子": "包子",
            "饺子": "饺子", "交子": "饺子", "叫子": "饺子",
            "意面": "意面", "一面": "意面",
            
            // 调料类
            "生抽": "生抽", "声抽": "生抽", "升抽": "生抽",
            "老抽": "老抽", "劳抽": "老抽", "捞抽": "老抽",
            "香油": "香油", "想油": "香油", "向油": "香油",
            "胡椒": "胡椒", "湖椒": "胡椒", "狐椒": "胡椒",
            "八角": "八角", "把角": "八角", "巴角": "八角",
            "迷迭香": "迷迭香", "你爹想": "迷迭香",
            
            // 海鲜类
            "三文鱼": "三文鱼", "三纹鱼": "三文鱼", "山文鱼": "三文鱼",
            "金枪鱼": "金枪鱼", "金抢鱼": "金枪鱼",
            "带鱼": "带鱼", "戴鱼": "带鱼", "待鱼": "带鱼",
            "鱿鱼": "鱿鱼", "游鱼": "鱿鱼", "尤鱼": "鱿鱼",
            "扇贝": "扇贝", "闪贝": "扇贝", "善贝": "扇贝",
            "生蚝": "生蚝", "声蚝": "生蚝", "升蚝": "生蚝",
            
            // 饮品类
            "可乐": "可乐", "渴乐": "可乐", "克乐": "可乐",
            "雪碧": "雪碧", "雪璧": "雪碧", "学碧": "雪碧",
            "果汁": "果汁", "过汁": "果汁", "国汁": "果汁",
            "咖啡": "咖啡", "卡啡": "咖啡", "卡非": "咖啡"
        ]
        
        for (wrong, correct) in corrections {
            correctedText = correctedText.replacingOccurrences(of: wrong, with: correct)
        }
        
        // 清理多余的空格
        correctedText = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        correctedText = correctedText.replacingOccurrences(of: "  ", with: " ")
        
        // 容器上下文智能检测
        correctedText = applyContainerContextCorrections(correctedText)
        
        // 最后处理单独的"奶"字映射（确保不影响已有的完整词汇）
        correctedText = applySingleCharacterMilkCorrection(correctedText)
        
        // 恢复保护的时间词汇
        for (placeholder, originalWord) in protectedMap {
            correctedText = correctedText.replacingOccurrences(of: placeholder, with: originalWord)
        }
        
        return correctedText
    }
    
    // 单独的"奶"字映射处理
    private func applySingleCharacterMilkCorrection(_ text: String) -> String {
        // 使用正则表达式只匹配单独的"奶"字，不影响"酸奶"、"牛奶"等完整词汇
        let regex = try! NSRegularExpression(pattern: "(?<![\\u4e00-\\u9fff])奶(?![\\u4e00-\\u9fff])")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "牛奶")
    }
    
    // 容器上下文智能检测
    private func applyContainerContextCorrections(_ text: String) -> String {
        var correctedText = text
        
        // 首先保护已经完整的奶制品名称，避免被误纠正
        let protectedDairyTerms = ["酸奶", "牛奶", "羊奶", "豆奶", "椰奶", "杏仁奶", "燕麦奶", "奶酪", "奶油"]
        var protectedMap: [String: String] = [:]
        
        // 临时替换保护词汇
        for (index, term) in protectedDairyTerms.enumerated() {
            if correctedText.contains(term) {
                let placeholder = "___DAIRY_PROTECTED_\(index)___"
                protectedMap[placeholder] = term
                correctedText = correctedText.replacingOccurrences(of: term, with: placeholder)
            }
        }
        
        // 只对单独的"奶"字进行容器上下文纠正
        let containerPatterns = [
            // 罐装通常是酸奶或奶制品 - 只匹配单独的"奶"字
            ("罐奶", "罐酸奶"),
            ("一罐奶", "一罐酸奶"),
            ("两罐奶", "两罐酸奶"),
            ("三罐奶", "三罐酸奶"),
            ("半罐奶", "半罐酸奶"),
            // 瓶装通常是牛奶 - 只匹配单独的"奶"字
            ("瓶奶", "瓶牛奶"),
            ("一瓶奶", "一瓶牛奶"),
            ("两瓶奶", "两瓶牛奶"),
            ("三瓶奶", "三瓶牛奶"),
            ("半瓶奶", "半瓶牛奶"),
            // 盒装通常是牛奶 - 只匹配单独的"奶"字
            ("盒奶", "盒牛奶"),
            ("一盒奶", "一盒牛奶"),
            ("两盒奶", "两盒牛奶"),
            ("三盒奶", "三盒牛奶"),
            ("半盒奶", "半盒牛奶"),
            // 袋装通常是牛奶 - 只匹配单独的"奶"字
            ("袋奶", "袋牛奶"),
            ("一袋奶", "一袋牛奶"),
            ("两袋奶", "两袋牛奶"),
            ("三袋奶", "三袋牛奶"),
            ("半袋奶", "半袋牛奶")
        ]
        
        // 应用容器纠正，但只对单独的"奶"字
        for (pattern, replacement) in containerPatterns {
            // 确保是单独的"奶"字，前面不能是其他汉字
            let regex = try! NSRegularExpression(pattern: "(?<![\\u4e00-\\u9fff])" + NSRegularExpression.escapedPattern(for: pattern) + "(?![\\u4e00-\\u9fff])")
            let range = NSRange(correctedText.startIndex..<correctedText.endIndex, in: correctedText)
            correctedText = regex.stringByReplacingMatches(in: correctedText, options: [], range: range, withTemplate: replacement)
        }
        
        // 恢复保护的完整奶制品名称
        for (placeholder, originalTerm) in protectedMap {
            correctedText = correctedText.replacingOccurrences(of: placeholder, with: originalTerm)
        }
        
        return correctedText
    }
    
    nonisolated private func applyEnglishParsingCorrections(to text: String) -> String {
        var correctedText = text.lowercased()
        
        correctedText = correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        correctedText = correctedText.replacingOccurrences(of: "  ", with: " ")
        
        return correctedText
    }
    
    // 数字映射 (中英文) - 注意：0.5会在单位处理时特别处理
    private let numberMappings: [String: Int] = [
        // 中文数字
        "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
        "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
        "两": 2, "俩": 2,
        // 英文数字
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "a": 1, "an": 1
    ]
    
    // 半数处理 - 需要与单位结合计算
    private let fractionalMappings: [String: Double] = [
        "半": 0.5,
        "个半": 1.5,
        "half": 0.5
    ]
    
    // 单位类型分类
    private enum UnitType {
        case weight    // 重量单位 → g
        case volume    // 体积单位 → mL  
        case count     // 计数单位 → 个
    }
    
    // 重量单位映射和转换系数 (目标单位: g)
    private let weightUnits: [String: Double] = [
        // 中文重量单位
        "公斤": 1000, "千克": 1000, "斤": 500, "两": 50, "钱": 5,
        "克": 1, "毫克": 0.001, "磅": 453.592, "盎司": 28.3495,
        // 英文重量单位  
        "kilogram": 1000, "kilograms": 1000, "kg": 1000,
        "gram": 1, "grams": 1, "g": 1, "milligram": 0.001, "mg": 0.001,
        "pound": 453.592, "pounds": 453.592, "lbs": 453.592, "lb": 453.592,
        "ounce": 28.3495, "ounces": 28.3495, "oz": 28.3495,
        "ton": 1000000, "tons": 1000000, "tonne": 1000000, "tonnes": 1000000
    ]
    
    // 体积单位映射和转换系数 (目标单位: mL)
    private let volumeUnits: [String: Double] = [
        // 中文体积单位
        "升": 1000, "公升": 1000, "毫升": 1, "微升": 0.001,
        "勺": 15, "汤勺": 15, "茶勺": 5, "杯": 250, "碗": 300,
        "瓶": 500, "罐": 330, "听": 330,
        "加仑": 3785.41, "美加仑": 3785.41, "英加仑": 4546.09,
        // 英文体积单位
        "liter": 1000, "liters": 1000, "L": 1000, "l": 1000,
        "milliliter": 1, "milliliters": 1, "mL": 1, "ml": 1,
        "microliter": 0.001, "microliters": 0.001, "μL": 0.001,
        "cup": 236.588, "cups": 236.588,
        "tablespoon": 14.7868, "tablespoons": 14.7868, "tbsp": 14.7868,
        "teaspoon": 4.92892, "teaspoons": 4.92892, "tsp": 4.92892,
        "quart": 946.353, "quarts": 946.353, "qt": 946.353,
        "pint": 473.176, "pints": 473.176, "pt": 473.176,
        "gallon": 3785.41, "gallons": 3785.41, "gal": 3785.41,
        "fluid ounce": 29.5735, "fluid ounces": 29.5735, "fl oz": 29.5735, "floz": 29.5735,
        // 英文容器单位 (映射到体积)
        "bottle": 500, "bottles": 500, "can": 330, "cans": 330, "jar": 400, "jars": 400,
        "carton": 1000, "cartons": 1000
    ]
    
    // 容器单位 (这些单位可能包含液体，需要特殊处理)
    private let containerUnits: Set<String> = [
        // 中文容器单位
        "瓶", "罐", "盒", "袋", "大瓶", "小瓶", "听", "桶", "缸", "坛", "壶", "杯", "碗",
        "塑料瓶", "玻璃瓶", "铁罐", "纸盒", "塑料袋", "纸袋", "保鲜盒", "密封盒",
        // 英文容器单位
        "bottle", "bottles", "can", "cans", "box", "boxes", "jar", "jars",
        "package", "packages", "pack", "packs", "bag", "bags", "container", "containers",
        "carton", "cartons", "tube", "tubes", "pouch", "pouches", "tin", "tins"
    ]
    
    // 计数单位 (转换为 "个")
    private let countUnits: Set<String> = [
        // 中文计数单位
        "个", "只", "条", "根", "片", "块", "段", "串", "把", "束", "朵", "头",
        "瓶", "罐", "盒", "包", "袋", "听", "桶", "缸", "坛", "壶", "杯", "碗",
        "大瓶", "小瓶", "大包", "小包", "大盒", "小盒", "件", "打", "对", "双", "副",
        "支", "枝", "棵", "株", "颗", "粒", "滴", "张", "本", "份", "盘", "碟",
        // 英文计数单位
        "piece", "pieces", "item", "items", "unit", "units",
        "bottle", "bottles", "can", "cans", "box", "boxes", "jar", "jars",
        "package", "packages", "pack", "packs", "bag", "bags", "container", "containers",
        "carton", "cartons", "tube", "tubes", "pouch", "pouches", "tin", "tins",
        "dozen", "dozens", "pair", "pairs", "set", "sets", "bundle", "bundles",
        "slice", "slices", "strip", "strips", "stick", "sticks", "sheet", "sheets"
    ]
    
    // 液体食物关键词
    private let liquidFoods: Set<String> = [
        // 中文液体 - 乳制品
        "牛奶", "酸奶", "豆奶", "椰奶", "杏仁奶", "燕麦奶", "羊奶", "奶昔", "酪乳", "鲜奶", "纯奶",
        "奶油", "淡奶油", "稀奶油", "炼乳", "甜炼乳",
        // 中文液体 - 果汁饮料
        "果汁", "橙汁", "苹果汁", "葡萄汁", "西瓜汁", "柠檬汁", "蔬菜汁", "胡萝卜汁", "西红柿汁",
        "汽水", "可乐", "雪碧", "芬达", "苏打水", "气泡水", "柠檬汽水", "运动饮料", "功能饮料",
        // 中文液体 - 茶类咖啡
        "茶", "绿茶", "红茶", "乌龙茶", "普洱茶", "花茶", "柠檬茶", "奶茶", "蜂蜜茶", "冰茶",
        "咖啡", "美式咖啡", "拿铁", "卡布奇诺", "摩卡", "浓缩咖啡", "冰咖啡", "速溶咖啡",
        // 中文液体 - 酒类
        "酒", "啤酒", "红酒", "白酒", "黄酒", "米酒", "料酒", "香槟", "威士忌", "伏特加", "白兰地", "朗姆酒",
        // 中文液体 - 水类
        "水", "矿泉水", "纯净水", "柠檬水", "蜂蜜水", "淡盐水", "苏打水",
        // 中文液体 - 调料酱料
        "醋", "白醋", "香醋", "米醋", "果醋", "油", "香油", "芝麻油", "橄榄油", "花生油", "菜籽油", "玉米油",
        "酱油", "生抽", "老抽", "蚝油", "鱼露", "料酒", "蜂蜜", "枫糖浆", "玉米糖浆",
        "番茄酱", "辣椒酱", "沙拉酱", "蛋黄酱", "芥末酱", "千岛酱", "韩式辣椒酱",
        // 中文液体 - 其他
        "豆浆", "椰汁", "杏仁露", "核桃露", "银耳汤", "绿豆汤", "红豆汤", "汤", "清汤", "浓汤",
        
        // 英文液体 - 乳制品
        "milk", "whole milk", "skim milk", "low fat milk", "yogurt", "greek yogurt", "kefir",
        "cream", "heavy cream", "whipping cream", "half and half", "buttermilk", "condensed milk",
        "coconut milk", "almond milk", "oat milk", "soy milk", "rice milk", "goat milk",
        // 英文液体 - 果汁饮料
        "juice", "orange juice", "apple juice", "grape juice", "cranberry juice", "tomato juice",
        "soda", "cola", "sprite", "ginger ale", "tonic water", "sparkling water", "sports drink",
        // 英文液体 - 茶类咖啡
        "tea", "green tea", "black tea", "herbal tea", "iced tea", "chai", "matcha",
        "coffee", "espresso", "americano", "latte", "cappuccino", "mocha", "macchiato", "frappuccino",
        // 英文液体 - 酒类
        "wine", "red wine", "white wine", "beer", "whiskey", "vodka", "rum", "gin", "brandy", "champagne",
        // 英文液体 - 水类
        "water", "mineral water", "spring water", "distilled water", "sparkling water", "tonic water",
        // 英文液体 - 调料酱料
        "vinegar", "apple cider vinegar", "balsamic vinegar", "rice vinegar", "white vinegar",
        "oil", "olive oil", "vegetable oil", "canola oil", "sesame oil", "coconut oil", "avocado oil",
        "soy sauce", "fish sauce", "oyster sauce", "honey", "maple syrup", "corn syrup", "agave",
        "ketchup", "mustard", "mayonnaise", "ranch", "thousand island", "hot sauce", "barbecue sauce",
        // 英文液体 - 其他
        "broth", "stock", "soup", "smoothie", "shake", "drink", "beverage", "sauce", "syrup"
    ]
    
    // 检查是否为有效单位
    private func isValidUnit(_ token: String) -> Bool {
        let lowercaseToken = token.lowercased()
        return weightUnits.keys.contains(lowercaseToken) || 
               volumeUnits.keys.contains(lowercaseToken) || 
               countUnits.contains(lowercaseToken)
    }
    
    // 检查食物是否为液体
    private func isLiquidFood(_ name: String) -> Bool {
        let lowercaseName = name.lowercased()
        return liquidFoods.contains { liquid in
            lowercaseName.contains(liquid.lowercased())
        }
    }
    
    // 检查是否使用了容器单位
    private func isContainerUnit(_ unit: String) -> Bool {
        return containerUnits.contains(unit.lowercased())
    }
    
    // 获取默认单位
    private func getDefaultUnit(quantity: Double = 1.0) -> (finalUnit: String, displayUnit: String, finalQuantity: Int, needsVolumeInput: Bool) {
        let currentLanguage = LocalizationManager.shared.selectedLanguage
        let displayUnit = currentLanguage == "en" ? "pcs" : "个"
        return (finalUnit: "个", displayUnit: displayUnit, finalQuantity: Int(quantity), needsVolumeInput: false)
    }
    
    // 单位处理辅助方法
    private func processUnit(token: String, quantity: Double, foodName: String = "") -> (finalUnit: String, displayUnit: String, finalQuantity: Int, needsVolumeInput: Bool) {
        let lowercaseToken = token.lowercased()
        
        // 检查重量单位
        if let weightFactor = weightUnits[lowercaseToken] {
            let totalGrams = Int(Double(quantity) * weightFactor)
            return (finalUnit: "g", displayUnit: "g", finalQuantity: totalGrams, needsVolumeInput: false)
        }
        
        // 检查体积单位
        if let volumeFactor = volumeUnits[lowercaseToken] {
            let totalML = Int(Double(quantity) * volumeFactor)
            return (finalUnit: "mL", displayUnit: "mL", finalQuantity: totalML, needsVolumeInput: false)
        }
        
        // 检查计数单位
        if countUnits.contains(lowercaseToken) {
            let currentLanguage = LocalizationManager.shared.selectedLanguage
            
            // 特殊处理"打"单位 - 1打 = 12个
            if lowercaseToken == "打" || lowercaseToken == "dozen" || lowercaseToken == "dozens" {
                let dozenQuantity = Int(quantity * 12) // 半打 = 0.5 * 12 = 6个
                let displayUnit = currentLanguage == "en" ? "pcs" : "个"
                return (finalUnit: "个", displayUnit: displayUnit, finalQuantity: dozenQuantity, needsVolumeInput: false)
            }
            
            let displayUnit = currentLanguage == "en" ? "pcs" : "个"
            
            // 特殊检查：如果是容器单位 + 液体食物，需要用户输入体积
            let needsVolume = isContainerUnit(token) && isLiquidFood(foodName)
            
            return (finalUnit: "个", displayUnit: displayUnit, finalQuantity: Int(quantity), needsVolumeInput: needsVolume)
        }
        
        // 默认按个计算
        let currentLanguage = LocalizationManager.shared.selectedLanguage
        let displayUnit = currentLanguage == "en" ? "pcs" : "个"
        return (finalUnit: "个", displayUnit: displayUnit, finalQuantity: Int(quantity), needsVolumeInput: false)
    }
        
    
    func parseVoiceInput(_ text: String) async -> [ParsedFoodItem] {
        print("[FoodItemParser] Starting to parse: '\(text)'")
        let purchaseDate = extractPurchaseDate(from: text)
        var rawComponents: [RawFoodComponent] = []
        
        // Clean and normalize the input text
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
        
        // Apply intelligent corrections for parsing while preserving display text
        let correctedTextForParsing = await applyParsingCorrections(to: cleanedText)
        print("[FoodItemParser] Corrected for parsing: '\(text)' → '\(correctedTextForParsing)'")
        
        // Pre-process text to remove expiration information to avoid including it in food names
        let textForParsing = cleanExpirationFromText(correctedTextForParsing)
        
        // Pre-process to handle quantity-container-volume patterns like "两瓶400ml"
        let expandedText = preprocessQuantityContainerVolume(textForParsing)
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = expandedText
        
        var currentQuantity: Double?
        var currentUnit: String?
        var currentDisplayUnit: String?
        var currentName = ""
        var pendingComponents: [RawFoodComponent] = [] // 存储待处理的数量-单位组合
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        // Step 1: Pre-process to extract number+unit combinations like "20磅" and handle "斤两" combinations
        let preprocessedText = preprocessNumberUnitCombinations(preprocessChineseWeightCombinations(expandedText))
        tagger.string = preprocessedText
        
        // Step 2: Synchronously parse text into raw components using improved logic
        tagger.enumerateTags(in: preprocessedText.startIndex..<preprocessedText.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let token = String(preprocessedText[tokenRange])
            let lowercaseToken = token.lowercased()
            
            // Enhanced stopword filtering - case insensitive
            // Special handling for "of" - don't treat it as a complete stopword in measurement contexts
            if FoodClassificationService.shared.isStopWord(lowercaseToken) && lowercaseToken != "of" {
                return true
            }
            
            // Skip "of" without ending current parsing context
            if lowercaseToken == "of" {
                print("[FoodItemParser] Skipping 'of'")
                return true
            }
            
            // Handle numbers (both Arabic and Chinese)
            if let number = Int(token) {
                // If we have accumulated a name, save it first
                if !currentName.isEmpty {
                    rawComponents.append(RawFoodComponent(name: currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit))
                    currentName = ""
                    currentUnit = nil
                    currentDisplayUnit = nil
                }
                currentQuantity = Double(number)
                return true
            }
            
            // 检查分数映射（如"半"）
            if let fractional = fractionalMappings[lowercaseToken] {
                // If we have accumulated a name, save it first
                if !currentName.isEmpty {
                    rawComponents.append(RawFoodComponent(name: currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit))
                    currentName = ""
                    currentUnit = nil
                    currentDisplayUnit = nil
                }
                currentQuantity = fractional
                return true
            }
            
            // 检查整数映射
            if let number = numberMappings[lowercaseToken] {
                // If we have accumulated a name, save it first
                if !currentName.isEmpty {
                    rawComponents.append(RawFoodComponent(name: currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit))
                    currentName = ""
                    currentUnit = nil
                    currentDisplayUnit = nil
                }
                currentQuantity = Double(number)
                return true
            }
            
            // Handle units - case insensitive with new unit system
            if isValidUnit(lowercaseToken) {
                // Check if this is a weight unit (which should be the primary unit)
                let isWeightUnit = weightUnits.keys.contains(lowercaseToken)
                let isVolumeUnit = volumeUnits.keys.contains(lowercaseToken)
                _ = countUnits.contains(lowercaseToken)
                
                // If we already have a current unit and quantity, decide how to handle it
                if currentUnit != nil && currentQuantity != nil {
                    let previousIsWeightOrVolume = weightUnits.keys.contains(currentUnit!) || volumeUnits.keys.contains(currentUnit!)
                    let currentIsWeightOrVolume = isWeightUnit || isVolumeUnit
                    
                    // Special handling for Chinese expression patterns like "一条两斤的鱼"
                    // If previous unit is a count unit and current is weight/volume, use weight/volume as primary
                    if !previousIsWeightOrVolume && currentIsWeightOrVolume {
                        // Don't store the count unit as a separate component
                        // Just update to use the weight/volume unit
                        print("[FoodItemParser] Replacing count unit '\(currentUnit ?? "")' with weight/volume unit '\(lowercaseToken)'")
                    } else {
                        // Otherwise, store the previous as a pending component
                        let tempComponent = RawFoodComponent(name: "", quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit)
                        pendingComponents.append(tempComponent)
                        print("[FoodItemParser] Stored pending component: \(currentQuantity ?? 1) \(currentUnit ?? "")")
                    }
                }
                
                // Store the new unit token for current processing
                currentUnit = lowercaseToken
                currentDisplayUnit = lowercaseToken
                // Don't return here - continue to collect food name after unit
                print("[FoodItemParser] Found unit: \(lowercaseToken) with quantity: \(currentQuantity ?? 1)")
                return true
            }
            
            // Handle different types of words
            if let tag = tag {
                switch tag {
                case .noun, .organizationName, .placeName, .personalName:
                    // Check if this token is a unit that was missed earlier
                    if isValidUnit(lowercaseToken) {
                        currentUnit = lowercaseToken
                        currentDisplayUnit = lowercaseToken
                        print("[FoodItemParser] Found unit in noun context: \(lowercaseToken) with quantity: \(currentQuantity ?? 1)")
                    } else {
                        // 检查当前名称是否已经是一个完整的食物
                        if !currentName.isEmpty && isFoodName(currentName) && isFoodName(token) {
                            // 如果当前名称和新词都是独立的食物名称，先保存当前的
                            rawComponents.append(RawFoodComponent(name: currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit))
                            currentName = token
                            currentQuantity = nil
                            currentUnit = nil
                            currentDisplayUnit = nil
                        } else {
                            // Only add space if currentName is not empty and we're not dealing with Chinese characters
                            if !currentName.isEmpty {
                                currentName += shouldAddSpaceBetweenTokens(currentName, token) ? " " + token : token
                            } else {
                                currentName = token
                            }
                        }
                        print("[FoodItemParser] Added to name (noun): currentName = '\(currentName)'")
                    }
                case .verb, .conjunction, .preposition, .adverb, .pronoun:
                    // Complete current item if we have a name
                    if !currentName.isEmpty {
                        print("[FoodItemParser] Completing item on verb/conjunction: '\(currentName)'")
                        rawComponents.append(RawFoodComponent(name: currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit))
                        currentQuantity = nil
                        currentUnit = nil
                        currentDisplayUnit = nil
                        currentName = ""
                    }
                default:
                    // Check if this token is a unit that was missed earlier
                    if isValidUnit(lowercaseToken) {
                        currentUnit = lowercaseToken
                        currentDisplayUnit = lowercaseToken
                        print("[FoodItemParser] Found unit in other context: \(lowercaseToken) with quantity: \(currentQuantity ?? 1)")
                    } else {
                        // For other word types, treat as potential food name
                        if !currentName.isEmpty {
                            currentName += shouldAddSpaceBetweenTokens(currentName, token) ? " " + token : token
                        } else {
                            currentName = token
                        }
                        print("[FoodItemParser] Added to name (other): currentName = '\(currentName)'")
                    }
                }
            } else {
                // Check if this token is a unit that was missed earlier
                if isValidUnit(lowercaseToken) {
                    currentUnit = lowercaseToken
                    currentDisplayUnit = lowercaseToken
                    print("[FoodItemParser] Found unit in no-tag context: \(lowercaseToken) with quantity: \(currentQuantity ?? 1)")
                } else {
                    // If no tag is available, treat as potential food name
                    if !currentName.isEmpty {
                        currentName += shouldAddSpaceBetweenTokens(currentName, token) ? " " + token : token
                    } else {
                        currentName = token
                    }
                    print("[FoodItemParser] Added to name (no tag): currentName = '\(currentName)'")
                }
            }
            return true
        }
        
        // Don't forget the last component
        if !currentName.isEmpty {
            var handled = false
            
            // Special handling: If we have pending components, check if they should be merged
            if !pendingComponents.isEmpty && currentUnit != nil {
                // Check if the current unit is weight/volume and pending is count
                let currentIsWeightOrVolume = weightUnits.keys.contains(currentUnit!) || volumeUnits.keys.contains(currentUnit!)
                
                if currentIsWeightOrVolume && pendingComponents.count == 1 {
                    let pending = pendingComponents[0]
                    let pendingIsCount = countUnits.contains(pending.unit ?? "")
                    
                    if pendingIsCount {
                        // This is likely a pattern like "一条两斤的鱼", merge into single item
                        print("[FoodItemParser] Merging count and weight units for '\(currentName)'")
                        let splitComponents = splitMultipleFoodNames(currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit)
                        rawComponents.append(contentsOf: splitComponents)
                        pendingComponents.removeAll()
                        handled = true
                    }
                }
            }
            
            // Normal processing if not handled by special case
            if !handled {
                // Add all pending components with the current food name
                for pendingComponent in pendingComponents {
                    let component = RawFoodComponent(name: currentName, quantity: pendingComponent.quantity, unit: pendingComponent.unit, displayUnit: pendingComponent.displayUnit)
                    rawComponents.append(component)
                    print("[FoodItemParser] Added pending component: \(pendingComponent.quantity ?? 1) \(pendingComponent.unit ?? "") \(currentName)")
                }
                
                // Then add the current component
                if currentQuantity != nil || currentUnit != nil {
                    let splitComponents = splitMultipleFoodNames(currentName, quantity: currentQuantity, unit: currentUnit, displayUnit: currentDisplayUnit)
                    rawComponents.append(contentsOf: splitComponents)
                }
            }
            
            // Clear pending components
            pendingComponents.removeAll()
        }
        
        print("[FoodItemParser] Found \(rawComponents.count) raw components:")
        for (index, component) in rawComponents.enumerated() {
            print("  [\(index)] name: '\(component.name)', quantity: \(component.quantity ?? 1.0), unit: \(component.unit ?? getLocalizedDefaultUnit())")
        }
        
        // Step 2: Process raw components - filter valid food names first
        let validComponents = rawComponents.compactMap { component -> (RawFoodComponent, String)? in
            let trimmedName = component.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检查是否为空或过短
            guard !trimmedName.isEmpty && trimmedName.count >= 2 else {
                print("[FoodItemParser] ❌ Filtered out: '\(trimmedName)' - too short or empty")
                return nil
            }
            
            // 检查是否包含无意义的重复字符 (如 "呜呜呜呜")
            if isNonsensicalText(trimmedName) {
                print("[FoodItemParser] ❌ Filtered out: '\(trimmedName)' - nonsensical text")
                return nil
            }
            
            // 检查是否为已知的食物名称
            if !isFoodName(trimmedName) {
                print("[FoodItemParser] ❌ Filtered out: '\(trimmedName)' - not a recognized food name")
                return nil
            }
            
            print("[FoodItemParser] ✅ Valid food name: '\(trimmedName)'")
            return (component, trimmedName)
        }
        
        guard !validComponents.isEmpty else {
            print("[FoodItemParser] ❌ No valid food names found in input: '\(text)'")
            return []
        }
        
        // Step 3: Batch process for AI classification
        let foodNames = validComponents.map { $0.1 }
        let aiResults = await batchInferCategory(from: foodNames)
        
        // Step 4: Create final results with parallel processing
        let results: [ParsedFoodItem] = await withTaskGroup(of: ParsedFoodItem?.self) { group in
            var parsedItems: [ParsedFoodItem] = []
            
            // 添加所有并行任务
            for (index, (component, trimmedName)) in validComponents.enumerated() {
                group.addTask { [cleanedText, purchaseDate] in
                    let (category, emoji) = aiResults[index]
                    
                    // Process units using new system
                    let baseQuantity = component.quantity ?? 1.0
                    let (finalUnit, displayUnit, finalQuantity, needsVolumeInput) = component.unit != nil ? 
                        self.processUnit(token: component.unit!, quantity: baseQuantity, foodName: trimmedName) :
                        self.getDefaultUnit(quantity: baseQuantity)
                    
                    // 获取推荐的存储位置
                    let recommendedStorage = StorageLocationRecommendationEngine.shared.recommendStorageLocation(for: trimmedName, category: category)
                    
                    // 并行计算过期日期
                    let expirationDate = await self.calculateSmartExpirationDate(
                        for: trimmedName, 
                        category: category, 
                        from: purchaseDate, 
                        userText: cleanedText,
                        storageLocation: recommendedStorage
                    )
                    
                    return ParsedFoodItem(
                        name: trimmedName,
                        quantity: finalQuantity,
                        unit: finalUnit,
                        displayUnit: displayUnit,
                        category: category,
                        purchaseDate: purchaseDate,
                        estimatedExpirationDate: expirationDate,
                        specificEmoji: emoji,
                        needsVolumeInput: needsVolumeInput,
                        recommendedStorageLocation: recommendedStorage,
                        storageLocation: recommendedStorage
                    )
                }
            }
            
            // 收集结果
            for await result in group {
                if let item = result {
                    parsedItems.append(item)
                }
            }
            
            return parsedItems
        }
        
        print("[FoodItemParser] Final results: \(results.count) items")
        for (index, item) in results.enumerated() {
            print("  [\(index)] \(item.name): \(item.quantity) \(item.unit), category: \(item.category)")
        }
        
        return results
    }
    
    private func extractPurchaseDate(from text: String) -> Date {
        let today = Date()
        
        if text.contains("今天") || text.contains("今日") || text.contains("刚买") {
            return today
        }
        
        if text.contains("昨天") {
            return Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        }
        
        return today
    }
    
    private func extractExpirationInfo(from text: String, itemName: String, purchaseDate: Date) -> Date? {
        let today = Date()
        let lowercaseText = text.lowercased()
        
        // 检查明确的过期时间表达
        // 中文表达
        if lowercaseText.contains("明天过期") || lowercaseText.contains("明天到期") {
            return Calendar.current.date(byAdding: .day, value: 1, to: today)
        }
        
        if lowercaseText.contains("今天过期") || lowercaseText.contains("今天到期") {
            return today
        }
        
        if lowercaseText.contains("后天过期") || lowercaseText.contains("后天到期") {
            return Calendar.current.date(byAdding: .day, value: 2, to: today)
        }
        
        // 新增：检查具体日期过期模式 "X月X号过期"
        let datePatterns = [
            // 中文月日格式 - 修正正则表达式以正确匹配
            "([0-9一二三四五六七八九十]+)月([0-9一二三四五六七八九十]+)号过期",
            "([0-9一二三四五六七八九十]+)月([0-9一二三四五六七八九十]+)号到期",
            "([0-9一二三四五六七八九十]+)月([0-9一二三四五六七八九十]+)日过期",
            "([0-9一二三四五六七八九十]+)月([0-9一二三四五六七八九十]+)日到期"
        ]
        
        for pattern in datePatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                let monthString = String(text[Range(match.range(at: 1), in: text)!])
                let dayString = String(text[Range(match.range(at: 2), in: text)!])
                
                // 转换中文数字
                var month: Int?
                var day: Int?
                
                if let numericMonth = Int(monthString) {
                    month = numericMonth
                } else if let chineseMonth = numberMappings[monthString] {
                    month = chineseMonth
                }
                
                if let numericDay = Int(dayString) {
                    day = numericDay
                } else if let chineseDay = numberMappings[dayString] {
                    day = chineseDay
                }
                
                if let month = month, let day = day, month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                    // 构建日期，假设是当年的日期
                    let calendar = Calendar.current
                    let currentYear = calendar.component(.year, from: today)
                    
                    var dateComponents = DateComponents()
                    dateComponents.year = currentYear
                    dateComponents.month = month
                    dateComponents.day = day
                    
                    if let expirationDate = calendar.date(from: dateComponents) {
                        // 如果日期已经过了，说明是明年的日期
                        let finalExpirationDate = expirationDate < today ? 
                            calendar.date(byAdding: .year, value: 1, to: expirationDate) ?? expirationDate : 
                            expirationDate
                        
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .none
                        print("[FoodItemParser] ✅ Found specific date expiry: \(formatter.string(from: finalExpirationDate)) for '\(itemName)'")
                        return finalExpirationDate
                    }
                }
            }
        }
        
        // 新增：检查英文月份+日期过期模式 (支持expired等变位)
        let englishDatePatterns = [
            // 英文月份全称模式
            "expir[eyd]+\\s+on\\s+(january|february|march|april|may|june|july|august|september|october|november|december)\\s+([0-9]{1,2})",
            "will\\s+expir[eyd]+\\s+on\\s+(january|february|march|april|may|june|july|august|september|october|november|december)\\s+([0-9]{1,2})",
            "(january|february|march|april|may|june|july|august|september|october|november|december)\\s+([0-9]{1,2})\\s+expir[eyd]+",
            "expir[eyd]+\\s+(january|february|march|april|may|june|july|august|september|october|november|december)\\s+([0-9]{1,2})",
            // 英文月份缩写模式
            "expir[eyd]+\\s+on\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+([0-9]{1,2})",
            "will\\s+expir[eyd]+\\s+on\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+([0-9]{1,2})",
            "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+([0-9]{1,2})\\s+expir[eyd]+",
            "expir[eyd]+\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+([0-9]{1,2})"
        ]
        
        let monthNameToNumber: [String: Int] = [
            "january": 1, "jan": 1,
            "february": 2, "feb": 2,
            "march": 3, "mar": 3,
            "april": 4, "apr": 4,
            "may": 5,
            "june": 6, "jun": 6,
            "july": 7, "jul": 7,
            "august": 8, "aug": 8,
            "september": 9, "sep": 9,
            "october": 10, "oct": 10,
            "november": 11, "nov": 11,
            "december": 12, "dec": 12
        ]
        
        for pattern in englishDatePatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                let monthString = String(text[Range(match.range(at: 1), in: text)!]).lowercased()
                let dayString = String(text[Range(match.range(at: 2), in: text)!])
                
                if let month = monthNameToNumber[monthString], 
                   let day = Int(dayString), 
                   month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                    
                    let calendar = Calendar.current
                    let currentYear = calendar.component(.year, from: today)
                    
                    var dateComponents = DateComponents()
                    dateComponents.year = currentYear
                    dateComponents.month = month
                    dateComponents.day = day
                    
                    if let expirationDate = calendar.date(from: dateComponents) {
                        // 如果日期已经过了，说明是明年的日期
                        let finalExpirationDate = expirationDate < today ? 
                            calendar.date(byAdding: .year, value: 1, to: expirationDate) ?? expirationDate : 
                            expirationDate
                        
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .none
                        print("[FoodItemParser] ✅ Found English date expiry: \(formatter.string(from: finalExpirationDate)) for '\(itemName)'")
                        return finalExpirationDate
                    }
                }
            }
        }
        
        // 检查 "X天后过期" 模式
        let patterns = [
            // 中文模式
            "([0-9一二三四五六七八九十]+)天后过期",
            "([0-9一二三四五六七八九十]+)天后到期",
            "过期时间?[是]?([0-9一二三四五六七八九十]+)天",
            // 英文模式 (支持expired等变位)
            "expires?\\s+in\\s+([0-9]+)\\s+days?",
            "expir[eyd]+\\s+([0-9]+)\\s+days?",
            "([0-9]+)\\s+days?\\s+(to\\s+)?expir[eyd]+"
        ]
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            if let match = regex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) {
                let dayString = String(text[Range(match.range(at: 1), in: text)!])
                
                // 转换中文数字
                var days: Int?
                if let numericDays = Int(dayString) {
                    days = numericDays
                } else if let chineseDays = numberMappings[dayString] {
                    days = chineseDays
                }
                
                if let days = days {
                    print("[FoodItemParser] ✅ Found explicit expiry: \(days) days from today for '\(itemName)'")
                    return Calendar.current.date(byAdding: .day, value: days, to: today)
                }
            }
        }
        
        print("[FoodItemParser] ⚠️ No explicit expiry found in text for '\(itemName)'")
        return nil
    }
    
    private func cleanExpirationFromText(_ text: String) -> String {
        var cleanedText = text
        
        // 定义需要清理的过期时间表达模式
        let expirationPatterns = [
            // 中文过期表达
            "明天过期", "明天到期", "今天过期", "今天到期", "后天过期", "后天到期",
            // 具体日期过期模式 - 关键新增和修正
            "[0-9一二三四五六七八九十]+月[0-9一二三四五六七八九十]+号过期",
            "[0-9一二三四五六七八九十]+月[0-9一二三四五六七八九十]+号到期",
            "[0-9一二三四五六七八九十]+月[0-9一二三四五六七八九十]+日过期",
            "[0-9一二三四五六七八九十]+月[0-9一二三四五六七八九十]+日到期",
            // 更完整的日期格式
            "[0-9]{1,2}/[0-9]{1,2}过期",
            "[0-9]{1,2}-[0-9]{1,2}过期",
            "[0-9]{4}年[0-9一二三四五六七八九十]+月[0-9一二三四五六七八九十]+号过期",
            "[0-9]{4}年[0-9一二三四五六七八九十]+月[0-9一二三四五六七八九十]+日过期",
            // 数字+天数模式
            "[0-9一二三四五六七八九十]+天后过期",
            "[0-9一二三四五六七八九十]+天后到期",
            "过期时间?[是]?[0-9一二三四五六七八九十]+天",
            // 英文过期表达 - 大幅增强 (支持各种动词变位)
            "expires?\\s+in\\s+[0-9]+\\s+days?",
            "expir[eyd]+\\s+[0-9]+\\s+days?",
            "[0-9]+\\s+days?\\s+(to\\s+)?expir[eyd]+",
            "expires?\\s+tomorrow",
            "expires?\\s+today",
            "expires?\\s+on\\s+[0-9]{1,2}/[0-9]{1,2}",
            "expires?\\s+[0-9]{1,2}/[0-9]{1,2}",
            // 新增：英文月份+日期模式 (支持expire/expired/expiry)
            "expir[eyd]+\\s+on\\s+(january|february|march|april|may|june|july|august|september|october|november|december)\\s+[0-9]{1,2}",
            "will\\s+expir[eyd]+\\s+on\\s+(january|february|march|april|may|june|july|august|september|october|november|december)\\s+[0-9]{1,2}",
            "(january|february|march|april|may|june|july|august|september|october|november|december)\\s+[0-9]{1,2}\\s+expir[eyd]+",
            "expir[eyd]+\\s+(january|february|march|april|may|june|july|august|september|october|november|december)\\s+[0-9]{1,2}",
            // 缩写月份模式 (支持expire/expired/expiry)
            "expir[eyd]+\\s+on\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+[0-9]{1,2}",
            "will\\s+expir[eyd]+\\s+on\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+[0-9]{1,2}",
            "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+[0-9]{1,2}\\s+expir[eyd]+",
            "expir[eyd]+\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+[0-9]{1,2}"
        ]
        
        // 逐个移除过期表达
        for pattern in expirationPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: cleanedText.count)
                cleanedText = regex.stringByReplacingMatches(in: cleanedText, options: [], range: range, withTemplate: "")
            } catch {
                // 如果正则表达式有问题，忽略这个模式
                continue
            }
        }
        
        // 清理多余的空格和标点
        cleanedText = cleanedText
            .replacingOccurrences(of: "，，", with: "，")
            .replacingOccurrences(of: ",,", with: ",")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedText
    }
    
    private func batchInferCategory(from names: [String]) async -> [(FoodCategory, String?)] {
        print("[FoodItemParser] 🏷️ Starting batch category inference for: \(names)")
        
        // 使用新的本地分类器
        let results = await localClassifier.classifyBatch(names: names)
        
        print("[FoodItemParser] 🏁 Final classification results:")
        for (index, result) in results.enumerated() {
            print("[FoodItemParser]   \(names[index]): \(result.0) \(result.1 ?? "nil")")
        }
        
        return results
    }
    
    private func inferCategory(from name: String) async -> (FoodCategory, String?) {
        // Use batch processing even for single items for consistency
        let results = await batchInferCategory(from: [name])
        return results.first ?? (.other, nil)
    }
    
    private func getLocalSpecificEmoji(for name: String) -> String? {
        return FoodClassificationService.shared.getSpecificEmoji(for: name)
    }

    private func inferCategoryWithKeywords(from name: String) -> FoodCategory {
        return FoodClassificationService.shared.classifyFood(name)
    }
    
    private func calculateExpirationDate(for category: FoodCategory, from purchaseDate: Date, itemName: String? = nil) -> Date? {
        let shelfLifeDays = FoodClassificationService.shared.getShelfLife(for: itemName ?? "", category: category)
        return Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: purchaseDate)
    }
    
    private func calculateSmartExpirationDate(for itemName: String, category: FoodCategory, from purchaseDate: Date, userText: String, storageLocation: StorageLocation) async -> Date? {
        print("[FoodItemParser] 🧠 Smart expiration calculation for '\(itemName)' (category: \(category))")
        
        // 步骤1: 首先尝试从用户语音中提取明确的过期日期
        print("[FoodItemParser] 🔍 Step 1: Checking for user-specified expiry in text: '\(userText)'")
        if let userSpecifiedExpiry = extractExpirationInfo(from: userText, itemName: itemName, purchaseDate: purchaseDate) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            print("[FoodItemParser] ✅ Step 1 SUCCESS: Using user-specified expiry date for '\(itemName)': \(formatter.string(from: userSpecifiedExpiry))")
            return userSpecifiedExpiry
        }
        print("[FoodItemParser] ❌ Step 1 FAILED: No user-specified expiry found")
        
        // 步骤2: 使用特定食物和存储位置计算过期日期
        print("[FoodItemParser] 🔍 Step 2: Using storage-aware shelf life calculation")
        let shelfLifeDays = StorageLocationRecommendationEngine.shared.getShelfLifeDays(for: itemName, category: category, storageLocation: storageLocation)
        let defaultExpiry = Calendar.current.date(byAdding: .day, value: shelfLifeDays, to: purchaseDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let expiryString = defaultExpiry != nil ? formatter.string(from: defaultExpiry!) : "unknown"
        print("[FoodItemParser] ✅ Step 2 SUCCESS: Using storage-aware shelf life (\(shelfLifeDays) days in \(storageLocation.localizedName)) → expires: \(expiryString)")
        return defaultExpiry
    }
    
    private func getLocalizedDefaultUnit() -> String {
        return FoodItem.defaultUnit
    }
    
    // 预处理函数：分离数字+单位组合如"20磅"
    // 处理中文"斤两"组合重量表达
    private func preprocessChineseWeightCombinations(_ text: String) -> String {
        var processedText = text
        
        // 处理"几斤几两"的表达模式
        let patterns = [
            // 数字+斤+数字+两 (如: 3斤5两, 一斤二两)
            "([0-9一二三四五六七八九十]+)斤([0-9一二三四五六七八九十]+)两",
            // 数字+斤+半两
            "([0-9一二三四五六七八九十]+)斤半两",
            // 数字+斤+两 (省略两的数量，默认为半两)
            "([0-9一二三四五六七八九十]+)斤两",
            // 半斤+数字+两
            "半斤([0-9一二三四五六七八九十]+)两",
            // 半斤半两
            "半斤半两",
            // 半斤两
            "半斤两"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: processedText.count)
                
                let matches = regex.matches(in: processedText, options: [], range: range)
                
                // 从后往前替换，避免位置偏移问题
                for match in matches.reversed() {
                    guard let matchRange = Range(match.range, in: processedText) else { continue }
                    let matchText = String(processedText[matchRange])
                    
                    let convertedWeight = convertChineseWeightToGrams(matchText)
                    let replacement = "\(convertedWeight) 克"
                    
                    processedText.replaceSubrange(matchRange, with: replacement)
                    print("[FoodItemParser] 斤两转换: '\(matchText)' → '\(replacement)'")
                }
            } catch {
                print("[FoodItemParser] 正则表达式错误: \(pattern)")
                continue
            }
        }
        
        return processedText
    }
    
    // 将中文重量表达转换为克数
    private func convertChineseWeightToGrams(_ weightText: String) -> Int {
        var totalGrams = 0
        
        // 解析斤的部分
        if let jinMatch = weightText.range(of: #"([0-9一二三四五六七八九十]+)斤"#, options: .regularExpression) {
            let jinStr = String(weightText[jinMatch]).replacingOccurrences(of: "斤", with: "")
            let jinValue = parseChineseNumber(jinStr)
            totalGrams += jinValue * 500 // 1斤 = 500克
        } else if weightText.contains("半斤") {
            totalGrams += 250 // 半斤 = 250克
        }
        
        // 解析两的部分
        if let liangMatch = weightText.range(of: #"([0-9一二三四五六七八九十]+)两"#, options: .regularExpression) {
            let liangStr = String(weightText[liangMatch]).replacingOccurrences(of: "两", with: "")
            let liangValue = parseChineseNumber(liangStr)
            totalGrams += liangValue * 50 // 1两 = 50克
        } else if weightText.contains("半两") {
            totalGrams += 25 // 半两 = 25克
        } else if weightText.hasSuffix("两") && !weightText.contains("几两") {
            // 只说"两"的情况，默认为半两
            totalGrams += 25
        }
        
        return totalGrams
    }
    
    // 解析中文数字
    private func parseChineseNumber(_ text: String) -> Int {
        // 如果是阿拉伯数字，直接转换
        if let number = Int(text) {
            return number
        }
        
        // 中文数字映射
        let chineseNumbers: [String: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
            "两": 2, "俩": 2, "半": 1 // 在这个上下文中，"半"按1计算，实际值会在调用处处理
        ]
        
        // 处理简单的中文数字
        if let value = chineseNumbers[text] {
            return value
        }
        
        // 处理"十几"的情况 (如: 十一, 十二, 等)
        if text.hasPrefix("十") && text.count > 1 {
            let remainder = String(text.dropFirst())
            if let remainderValue = chineseNumbers[remainder] {
                return 10 + remainderValue
            }
        }
        
        // 处理"几十"的情况 (如: 二十, 三十, 等)
        if text.hasSuffix("十") && text.count > 1 {
            let prefix = String(text.dropLast())
            if let prefixValue = chineseNumbers[prefix] {
                return prefixValue * 10
            }
        }
        
        // 处理"几十几"的情况 (如: 二十三, 五十八, 等)
        if text.contains("十") && text.count > 2 {
            let parts = text.components(separatedBy: "十")
            if parts.count == 2, 
               let tens = chineseNumbers[parts[0]], 
               let ones = chineseNumbers[parts[1]] {
                return tens * 10 + ones
            }
        }
        
        // 默认返回1，如果无法解析
        print("[FoodItemParser] 无法解析中文数字: '\(text)'，默认为1")
        return 1
    }
    
    private func preprocessQuantityContainerVolume(_ text: String) -> String {
        var processedText = text
        
        // 定义容器单位模式
        let containerUnits = ["瓶", "罐", "盒", "袋", "包", "bottle", "bottles", "can", "cans", "box", "boxes", "bag", "bags", "pack", "packs", "container", "containers"]
        
        // 定义数字模式（中文和阿拉伯数字）
        let chineseNumbers = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "两", "半"]
        let chineseNumberPattern = chineseNumbers.joined(separator: "|")
        
        // 定义体积单位模式
        let volumePattern = "([0-9]+(?:\\.[0-9]+)?)(ml|mL|毫升|l|L|升|gallon|加仑|cup|杯)"
        
        for containerUnit in containerUnits {
            // 匹配模式：[数字][容器单位][体积] 例如："两瓶400ml"、"3bottles250ml"
            // 阿拉伯数字模式
            let arabicPattern = "([0-9]+(?:\\.[0-9]+)?)\\s*\(NSRegularExpression.escapedPattern(for: containerUnit))\\s*\(volumePattern)"
            
            // 中文数字模式  
            let chinesePattern = "(\(chineseNumberPattern))\\s*\(NSRegularExpression.escapedPattern(for: containerUnit))\\s*\(volumePattern)"
            
            // 处理阿拉伯数字模式
            processedText = processPattern(processedText, pattern: arabicPattern, isChineseNumber: false)
            
            // 处理中文数字模式
            processedText = processPattern(processedText, pattern: chinesePattern, isChineseNumber: true)
        }
        
        if processedText != text {
            print("[FoodItemParser] Quantity-Container-Volume expansion: '\(text)' → '\(processedText)'")
        }
        
        return processedText
    }
    
    private func processPattern(_ text: String, pattern: String, isChineseNumber: Bool) -> String {
        var processedText = text
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: text.count)
            
            // 找到所有匹配项
            let matches = regex.matches(in: text, options: [], range: range)
            
            // 倒序处理匹配项，避免位置偏移
            for match in matches.reversed() {
                guard let quantityRange = Range(match.range(at: 1), in: text),
                      let volumeRange = Range(match.range(at: 2), in: text),
                      let unitRange = Range(match.range(at: 3), in: text) else {
                    continue
                }
                
                let quantityStr = String(text[quantityRange])
                let volumeStr = String(text[volumeRange])
                let unitStr = String(text[unitRange])
                
                // 转换数量
                let quantity: Double
                if isChineseNumber {
                    quantity = convertChineseNumberToDouble(quantityStr)
                } else {
                    quantity = Double(quantityStr) ?? 1.0
                }
                
                // 生成扩展文本：将"两瓶400ml"扩展为"400ml 400ml"
                var expandedItems: [String] = []
                let intQuantity = Int(quantity)
                
                for _ in 0..<intQuantity {
                    expandedItems.append("\(volumeStr)\(unitStr)")
                }
                
                let replacement = expandedItems.joined(separator: " ")
                
                // 替换匹配的文本
                if let matchRange = Range(match.range, in: text) {
                    let prefix = String(text[..<matchRange.lowerBound])
                    let suffix = String(text[matchRange.upperBound...])
                    processedText = prefix + replacement + suffix
                }
            }
        } catch {
            print("[FoodItemParser] Regex error in processPattern: \(error)")
        }
        
        return processedText
    }
    
    private func convertChineseNumberToDouble(_ text: String) -> Double {
        let chineseNumberMap: [String: Double] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
            "两": 2, "半": 0.5
        ]
        
        return chineseNumberMap[text] ?? 1.0
    }
    
    private func preprocessNumberUnitCombinations(_ text: String) -> String {
        var processedText = text
        
        // 创建所有单位的正则表达式模式
        var allUnits: Set<String> = []
        allUnits.formUnion(weightUnits.keys)
        allUnits.formUnion(volumeUnits.keys)
        allUnits.formUnion(countUnits)
        
        // 按长度排序，先匹配较长的单位（避免"公斤"被"克"误匹配）
        let sortedUnits = allUnits.sorted { $0.count > $1.count }
        
        for unit in sortedUnits {
            // 匹配数字+单位的模式，如"20磅"、"2公斤"
            let pattern = "([0-9]+)" + NSRegularExpression.escapedPattern(for: unit)
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: processedText.count)
                
                processedText = regex.stringByReplacingMatches(
                    in: processedText,
                    options: [],
                    range: range,
                    withTemplate: "$1 " + unit
                )
            } catch {
                // 如果正则表达式失败，继续处理其他单位
                continue
            }
        }
        
        print("[FoodItemParser] Preprocessed text: '\(text)' → '\(processedText)'")
        return processedText
    }
    
    // 检查文本是否为无意义的重复字符或噪音
    private func isNonsensicalText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否包含过多重复字符
        let characters = Array(trimmed)
        if characters.count >= 4 {
            // 检查是否有相同字符重复超过3次
            var repeatCount = 1
            var lastChar = characters[0]
            
            for i in 1..<characters.count {
                if characters[i] == lastChar {
                    repeatCount += 1
                    if repeatCount > 3 {
                        return true
                    }
                } else {
                    repeatCount = 1
                    lastChar = characters[i]
                }
            }
        }
        
        // 检查是否只包含语气词或噪音字符
        let noisyPatterns = ["呜", "啊", "哦", "嗯", "额", "唉", "哎", "诶"]
        let textLower = trimmed.lowercased()
        
        for pattern in noisyPatterns {
            if textLower.replacingOccurrences(of: pattern, with: "").isEmpty {
                return true
            }
        }
        
        return false
    }
    
    // 检查一个词是否是已知的食物名称
    private func isFoodName(_ name: String) -> Bool {
        // 使用关键词匹配来检查，避免异步调用
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否在已知食物关键词中
        let knownFoodKeywords: Set<String> = [
            // 常见水果
            "苹果", "香蕉", "橙子", "柠檬", "葡萄", "草莓", "西瓜", "梨", "桃子", "芒果", "菠萝", "猕猴桃",
            "樱桃", "李子", "杏", "石榴", "柚子", "橘子", "桔子", "哈密瓜", "火龙果", "榴莲", "椰子",
            // 常见蔬菜
            "白菜", "菠菜", "韭菜", "芹菜", "生菜", "油菜", "胡萝卜", "萝卜", "土豆", "红薯", "洋葱",
            "大蒜", "生姜", "西红柿", "黄瓜", "茄子", "辣椒", "青椒", "豆角", "花菜", "西兰花", "卷心菜",
            "蘑菇", "香菇", "金针菇", "木耳", "银耳", "豆腐", "豆芽",
            // 常见肉类和海鲜
            "猪肉", "牛肉", "鸡肉", "鸭肉", "羊肉", "鱼", "虾", "蟹", "鸡蛋", "鸭蛋", "香肠", "火腿", "培根",
            "鲈鱼", "鲤鱼", "草鱼", "鲫鱼", "带鱼", "黄鱼", "三文鱼", "金枪鱼", "鳕鱼", "龙虾", "扇贝", "生蚝",
            // 常见主食
            "大米", "面粉", "面包", "面条", "饺子", "包子", "馒头",
            // 常见调料
            "盐", "糖", "醋", "酱油", "油", "蜂蜜",
            // 常见饮料
            "牛奶", "酸奶", "果汁", "茶", "咖啡", "水", "可乐", "啤酒",
            // 英文常见食物
            "apple", "banana", "orange", "lemon", "grape", "strawberry", "watermelon", "pear",
            "potato", "tomato", "onion", "garlic", "carrot", "cabbage", "mushroom", "tofu",
            "pork", "beef", "chicken", "fish", "egg", "milk", "bread", "rice", "noodles",
            "sausage", "ham", "bacon", "salmon", "tuna", "shrimp", "crab", "bass", "lobster"
        ]
        
        // 检查完全匹配
        if knownFoodKeywords.contains(normalizedName) {
            return true
        }
        
        // 检查部分匹配
        for keyword in knownFoodKeywords {
            if normalizedName.contains(keyword) || keyword.contains(normalizedName) {
                return true
            }
        }
        
        return false
    }
    
    // 分割可能包含多个食物的名称
    private func splitMultipleFoodNames(_ name: String, quantity: Double?, unit: String?, displayUnit: String?) -> [RawFoodComponent] {
        var components: [RawFoodComponent] = []
        
        // 特殊处理：如果名称中包含多个已知食物，尝试分割
        let words = name.components(separatedBy: " ")
        if words.count == 2 && isFoodName(words[0]) && isFoodName(words[1]) {
            // 如果是两个独立的食物名称，分别创建组件
            components.append(RawFoodComponent(name: words[0], quantity: quantity, unit: unit, displayUnit: displayUnit))
            components.append(RawFoodComponent(name: words[1], quantity: 1.0, unit: nil, displayUnit: nil))
        } else {
            // 否则保持原样
            components.append(RawFoodComponent(name: name, quantity: quantity, unit: unit, displayUnit: displayUnit))
        }
        
        return components
    }
}
