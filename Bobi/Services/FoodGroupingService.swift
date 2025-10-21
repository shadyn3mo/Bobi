import Foundation
import NaturalLanguage

class FoodGroupingService {
    static let shared = FoodGroupingService()
    
    private init() {}
    
    // 基础食物词根映射 - 用于智能匹配
    private let baseFoodMappings: [String: Set<String>] = [
        // 中文基础食物
        "八角": ["八角", "大料"],
        "白菜": ["白菜", "大白菜", "小白菜", "娃娃菜", "奶白菜", "百菜", "摆菜"],
        "包子": ["包子", "包紫", "宝子"],
        "菠菜": ["菠菜", "波菜", "拨菜"],
        "菠萝": ["菠萝", "凤梨", "大菠萝", "小菠萝", "新鲜菠萝"],
        "草莓": ["草莓", "草没", "草美"],
        "橙子": ["橙子", "脐橙", "血橙", "甜橙", "冰糖橙", "成子", "承子"],
        "葱": ["葱", "大葱", "小葱", "香葱"],
        "醋": ["苹果醋", "米醋", "白醋", "陈醋", "香醋", "醋"],
        "大米": ["大米", "米饭", "东北大米", "泰国香米", "长粒米", "打米", "大迷"],
        "大蒜": ["大蒜", "蒜", "蒜头", "紫皮蒜", "白皮蒜"],
        "豆角": ["豆角", "四季豆", "芸豆", "豇豆"],
        "豆浆": ["豆浆", "豆奶"],
        "豆芽": ["豆芽", "绿豆芽", "黄豆芽"],
        "豆腐": ["豆腐", "老豆腐", "嫩豆腐", "内酯豆腐", "北豆腐", "南豆腐"],
        "冬瓜": ["冬瓜"],
        "腐竹": ["腐竹", "豆腐皮"],
        "蛤蜊": ["蛤蜊", "花蛤", "文蛤"],
        "桂皮": ["桂皮"],
        "海带": ["海带"],
        "蚝油": ["蚝油"],
        "花菜": ["花菜", "菜花", "花椰菜"],
        "花椒": ["花椒", "麻椒"],
        "黄瓜": ["黄瓜", "小黄瓜", "青瓜", "刺黄瓜", "水果黄瓜", "黄挂", "皇瓜"],
        "黄油": ["黄油", "butter"],
        "火龙果": ["火龙果", "火龙国", "伙龙果"],
        "火腿": ["火腿", "金华火腿", "云南火腿", "西班牙火腿", "意大利火腿", "火腿片", "火腿肠"],
        "鸡蛋": ["鸡蛋", "土鸡蛋", "柴鸡蛋", "散养鸡蛋", "普通鸡蛋", "有机鸡蛋", "笨鸡蛋", "草鸡蛋", "走地鸡蛋", "新鲜鸡蛋", "白皮鸡蛋", "红皮鸡蛋"],
        "鸡精": ["鸡精"],
        "鸡肉": ["鸡肉", "鸡胸肉", "鸡腿", "鸡翅", "鸡爪", "整鸡", "土鸡"],
        "茄子": ["茄子", "圆茄子", "长茄子"],
        "芥末": ["芥末", "辣根"],
        "酱油": ["酱油", "生抽", "老抽", "味极鲜", "蒸鱼豉油"],
        "饺子": ["饺子", "水饺", "交子", "叫子"],
        "金针菇": ["金针菇"],
        "韭菜": ["韭菜", "韭黄", "韭菜花", "九菜", "救菜"],
        "橘子": ["橘子", "桔子", "砂糖橘", "沃柑", "蜜橘", "贡柑", "椪柑"],
        "苦瓜": ["苦瓜"],
        "辣椒": ["辣椒", "尖椒", "螺丝椒", "朝天椒", "小米椒", "二荆条"],
        "梨": ["梨", "鸭梨", "雪梨", "香梨", "贡梨", "砀山梨", "秋月梨"],
        "料酒": ["料酒", "黄酒"],
        "莲藕": ["莲藕", "藕"],
        "芦笋": ["芦笋", "石刁柏"],
        "罗勒": ["罗勒", "九层塔"],
        "鲈鱼": ["鲈鱼", "欧洲鲈鱼", "美洲鲈鱼", "海鲈鱼", "淡水鲈鱼"],
        "馒头": ["馒头", "蛮头", "满头"],
        "芒果": ["芒果"],
        "面粉": ["面粉", "高筋面粉", "中筋面粉", "低筋面粉", "全麦粉"],
        "面条": ["面条", "拉面", "挂面", "面跳", "面调"],
        "面包": ["面包", "吐司", "面抱", "面报"],
        "猕猴桃": ["猕猴桃", "奇异果", "弥猴桃", "迷猴桃"],
        "蘑菇": ["蘑菇", "香菇", "平菇", "杏鲍菇", "草菇", "口蘑"],
        "木耳": ["木耳", "黑木耳"],
        "奶酪": ["奶酪", "芝士", "来酪", "奶老"],
        "南瓜": ["南瓜"],
        "柠檬": ["柠檬", "宁檬", "凝檬"],
        "牛肉": ["牛肉", "牛排", "牛腩", "牛腱", "牛里脊", "牛胸肉", "牛尾"],
        "牛油果": ["牛油果", "鳄梨"],
        "牛奶": ["牛奶", "纯牛奶", "全脂牛奶", "脱脂牛奶", "低脂牛奶", "有机牛奶", "鲜牛奶"],
        "苹果": ["苹果", "红苹果", "绿苹果", "青苹果", "黄苹果", "嘎啦苹果", "富士苹果", "蛇果"],
        "葡萄": ["葡萄", "红葡萄", "绿葡萄", "黑葡萄", "提子", "红提", "青提", "巨峰葡萄", "夏黑", "铺萄", "扑萄"],
        "芹菜": ["芹菜", "秦菜", "琴菜"],
        "青椒": ["青椒", "甜椒", "彩椒", "红椒", "黄椒", "青叫", "清椒"],
        "三文鱼": ["三文鱼", "鲑鱼", "大西洋三文鱼", "太平洋三文鱼", "挪威三文鱼"],
        "沙拉酱": ["沙拉酱", "蛋黄酱", "千岛酱"],
        "山药": ["山药", "淮山"],
        "扇贝": ["扇贝", "闪贝", "善贝"],
        "生菜": ["生菜", "莴苣", "罗马生菜"],
        "生蚝": ["生蚝", "牡蛎", "声蚝", "升蚝"],
        "生姜": ["生姜", "姜", "老姜", "嫩姜", "小黄姜"],
        "食用油": ["食用油", "花生油", "菜籽油", "大豆油", "玉米油", "葵花籽油", "橄榄油"],
        "糖": ["糖", "白糖", "红糖", "冰糖"],
        "桃子": ["桃子", "水蜜桃", "黄桃", "油桃", "蟠桃", "白桃"],
        "土豆": ["土豆", "马铃薯", "洋芋", "大土豆", "小土豆", "红皮土豆"],
        "味精": ["味精"],
        "莴笋": ["莴笋"],
        "虾": ["虾", "大虾", "小虾", "虾仁", "基围虾"],
        "香菜": ["香菜", "芫荽"],
        "香蕉": ["香蕉", "大香蕉", "小香蕉", "进口香蕉", "国产香蕉"],
        "香叶": ["香叶"],
        "香油": ["香油", "芝麻油"],
        "小茴香": ["小茴香"],
        "西瓜": ["西瓜", "大西瓜", "小西瓜", "甜西瓜", "无籽西瓜", "黑美人西瓜", "麒麟瓜", "切开的西瓜"],
        "西红柿": ["西红柿", "番茄", "小番茄", "樱桃番茄", "圣女果", "大番茄"],
        "西葫芦": ["西葫芦"],
        "西蓝花": ["西蓝花", "西兰花", "绿花菜"],
        "蟹": ["蟹", "螃蟹", "大闸蟹", "梭子蟹"],
        "鳕鱼": ["鳕鱼", "银鳕鱼", "黑鳕鱼"],
        "盐": ["盐", "食盐"],
        "燕麦": ["燕麦", "燕麦片"],
        "羊肉": ["羊肉", "羊腿", "羊排", "羊肉串"],
        "洋葱": ["洋葱", "白洋葱", "红洋葱", "紫洋葱", "小洋葱"],
        "意面": ["意面", "意大利面", "一面"],
        "油菜": ["油菜", "上海青", "小油菜"],
        "鱿鱼": ["鱿鱼", "游鱼", "尤鱼"],
        "玉米": ["玉米", "甜玉米", "糯玉米"],
        "猪肉": ["猪肉", "猪排", "猪腩", "猪腱", "里脊肉", "五花肉", "猪蹄"],
        "竹笋": ["竹笋", "冬笋", "春笋"],
        "孜然": ["孜然", "孜然粉"],
        "紫菜": ["紫菜", "海苔"],
        "紫苏叶": ["紫苏叶"],
        
        // 英文基础食物
        "apple": ["apple", "apples", "red apple", "green apple", "gala apple", "fuji apple"],
        "asparagus": ["asparagus"],
        "avocado": ["avocado", "alligator pear"],
        "bamboo shoot": ["bamboo shoot"],
        "banana": ["banana", "bananas", "large banana", "small banana", "organic banana"],
        "basil": ["basil"],
        "bay leaf": ["bay leaf"],
        "bean sprout": ["bean sprout"],
        "beef": ["beef", "ground beef", "beef steak", "beef roast", "beef brisket", "beef ribs"],
        "bell pepper": ["bell pepper", "green pepper", "red pepper", "yellow pepper"],
        "bitter melon": ["bitter melon"],
        "blueberry": ["blueberry", "blueberries"],
        "bread": ["bread", "toast"],
        "broccoli": ["broccoli"],
        "bun": ["bun", "baozi"],
        "butter": ["butter", "salted butter", "unsalted butter"],
        "cabbage": ["cabbage", "napa cabbage", "chinese cabbage"],
        "carrot": ["carrot", "carrots", "baby carrot", "large carrot", "organic carrot"],
        "cauliflower": ["cauliflower"],
        "celery": ["celery"],
        "cheese": ["cheese", "cheddar", "mozzarella"],
        "cherry": ["cherry", "cherries"],
        "chicken": ["chicken", "chicken breast", "chicken thigh", "chicken wings", "whole chicken", "chicken drumstick"],
        "chicken bouillon": ["chicken bouillon", "chicken stock powder"],
        "chili": ["chili", "chili pepper", "jalapeno"],
        "chives": ["chives"],
        "cilantro": ["cilantro", "coriander"],
        "cinnamon": ["cinnamon"],
        "clam": ["clam", "clams"],
        "cod": ["cod", "black cod", "pacific cod", "atlantic cod"],
        "cooking oil": ["cooking oil", "vegetable oil", "peanut oil", "canola oil", "olive oil", "sunflower oil", "corn oil"],
        "cooking wine": ["cooking wine", "shaoxing wine"],
        "corn": ["corn", "sweet corn"],
        "crab": ["crab"],
        "crown daisy": ["crown daisy"],
        "cucumber": ["cucumber", "cucumbers", "english cucumber", "persian cucumber"],
        "cumin": ["cumin"],
        "dragon fruit": ["dragon fruit"],
        "duck": ["duck"],
        "dumpling": ["dumpling", "jiaozi"],
        "egg": ["egg", "eggs", "free range eggs", "organic eggs", "brown eggs", "white eggs", "fresh eggs", "large eggs", "medium eggs", "small eggs"],
        "eggplant": ["eggplant", "aubergine"],
        "fennel seed": ["fennel seed"],
        "flour": ["flour", "all purpose flour", "bread flour"],
        "garlic": ["garlic", "garlic clove", "garlic cloves", "fresh garlic"],
        "ginger": ["ginger", "fresh ginger", "young ginger", "ginger root"],
        "glutinous rice": ["glutinous rice", "sticky rice"],
        "grapes": ["grapes", "red grapes", "green grapes", "seedless grapes"],
        "green bean": ["green bean", "string bean"],
        "ham": ["ham", "honey ham", "black forest ham", "virginia ham", "spiral ham", "ham slices"],
        "honey": ["honey"],
        "ketchup": ["ketchup", "tomato sauce"],
        "kelp": ["kelp"],
        "kiwi": ["kiwi"],
        "lamb": ["lamb", "mutton"],
        "laver": ["laver", "nori", "seaweed"],
        "lemon": ["lemon", "lemons"],
        "lettuce": ["lettuce", "romaine lettuce", "iceberg lettuce"],
        "lettuce stem": ["lettuce stem", "asparagus lettuce"],
        "lotus root": ["lotus root"],
        "mango": ["mango", "mangoes"],
        "milk": ["milk", "whole milk", "skim milk", "low fat milk", "organic milk", "fresh milk"],
        "millet": ["millet"],
        "msg": ["msg", "monosodium glutamate"],
        "mushroom": ["mushroom", "shiitake mushroom", "oyster mushroom", "king oyster mushroom", "button mushroom"],
        "mustard": ["mustard"],
        "noodles": ["noodles", "ramen"],
        "oat": ["oat", "oatmeal"],
        "onion": ["onion", "onions", "white onion", "red onion", "yellow onion"],
        "orange": ["orange", "navel orange", "blood orange"],
        "oyster": ["oyster"],
        "oyster sauce": ["oyster sauce"],
        "pasta": ["pasta", "spaghetti"],
        "peach": ["peach", "white peach", "yellow peach", "nectarine"],
        "pear": ["pear", "asian pear"],
        "perilla leaf": ["perilla leaf"],
        "pineapple": ["pineapple", "pineapples", "fresh pineapple", "canned pineapple", "pineapple chunks"],
        "pork": ["pork", "pork chop", "pork tenderloin", "ground pork", "pork shoulder", "pork ribs"],
        "potato": ["potato", "potatoes", "russet potato", "red potato", "small potato"],
        "pumpkin": ["pumpkin"],
        "rapeseed": ["rapeseed", "yu choy"],
        "rice": ["rice", "jasmine rice", "basmati rice"],
        "salad dressing": ["salad dressing", "mayonnaise", "thousand island"],
        "salt": ["salt", "table salt"],
        "scallion": ["scallion", "green onion", "spring onion"],
        "scallop": ["scallop"],
        "sesame oil": ["sesame oil"],
        "shrimp": ["shrimp", "prawn"],
        "sichuan peppercorn": ["sichuan peppercorn"],
        "soy sauce": ["soy sauce", "light soy sauce", "dark soy sauce"],
        "soy milk": ["soy milk"],
        "spinach": ["spinach"],
        "squid": ["squid"],
        "star anise": ["star anise"],
        "steamed bun": ["steamed bun"],
        "strawberry": ["strawberry", "strawberries"],
        "sugar": ["sugar", "white sugar", "brown sugar", "rock sugar"],
        "sweet potato": ["sweet potato"],
        "tangerine": ["tangerine", "mandarin"],
        "tofu": ["tofu", "firm tofu", "soft tofu", "silken tofu"],
        "tofu skin": ["tofu skin", "bean curd skin"],
        "tomato": ["tomato", "tomatoes", "cherry tomato", "cherry tomatoes", "large tomato"],
        "water spinach": ["water spinach"],
        "watermelon": ["watermelon", "watermelons", "large watermelon", "small watermelon", "sweet watermelon", "seedless watermelon", "cut watermelon"],
        "winter melon": ["winter melon"],
        "yam": ["yam", "chinese yam"],
        "yogurt": ["yogurt", "yoghurt", "greek yogurt", "plain yogurt", "flavored yogurt", "organic yogurt", "low fat yogurt"]
    ]
    
    // 颜色/形容词前缀 - 中英文
    private let adjectives: Set<String> = [
        // 中文形容词
        "红", "绿", "黄", "白", "黑", "紫", "蓝", "大", "小", "新鲜", "有机", "进口", "国产",
        "嫩", "老", "甜", "酸", "辣", "脆", "软", "硬", "鲜", "干", "湿",
        // 英文形容词
        "red", "green", "yellow", "white", "black", "purple", "blue", "large", "small", "big", "tiny",
        "fresh", "organic", "imported", "local", "sweet", "sour", "spicy", "crisp", "soft", "hard",
        "young", "old", "new", "ripe", "unripe"
    ]
    
    // 通用量词和包装词 - 中英文
    private let quantifiers: Set<String> = [
        // 中文量词
        "个", "只", "条", "根", "片", "块", "颗", "粒", "把", "束", "袋", "包", "盒", "瓶", "罐",
        // 英文量词
        "piece", "pieces", "slice", "slices", "bunch", "bag", "package", "box", "bottle", "can"
    ]
    
    /// 获取食物的基础名称（去除形容词和量词）
    func getBaseFoodName(_ foodName: String) -> String {
        var normalizedName = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除中文食物名称中的内部空格
        normalizedName = removeInternalSpacesFromChinese(normalizedName)
        
        // 检查是否直接匹配某个基础食物类别
        for (baseFood, variants) in baseFoodMappings {
            if variants.contains(normalizedName) {
                return baseFood
            }
        }
        
        // 使用 NLP 分析提取核心名词
        return extractCoreFoodName(from: normalizedName)
    }
    
    /// 移除中文字符间的空格
    private func removeInternalSpacesFromChinese(_ text: String) -> String {
        // 如果文本包含中文字符，移除所有空格
        let chineseRange = "\\p{Script=Han}"
        guard let chineseRegex = try? NSRegularExpression(pattern: chineseRange) else {
            return text
        }
        
        let textRange = NSRange(location: 0, length: text.utf16.count)
        let hasChinese = chineseRegex.firstMatch(in: text, options: [], range: textRange) != nil
        
        if hasChinese {
            // 如果包含中文，移除所有空格
            return text.replacingOccurrences(of: " ", with: "")
        }
        
        return text
    }
    
    /// 使用 NLP 提取核心食物名称
    private func extractCoreFoodName(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var nouns: [String] = []
        var allTokens: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let token = String(text[tokenRange])
            allTokens.append(token)
            
            // 跳过形容词和量词
            if adjectives.contains(token.lowercased()) || quantifiers.contains(token.lowercased()) {
                return true
            }
            
            // 收集名词
            if tag == .noun || tag == .organizationName {
                nouns.append(token)
            }
            
            return true
        }
        
        // 首先检查是否有明确的食物关键词
        for token in allTokens {
            let lowercaseToken = token.lowercased()
            for (baseFood, variants) in baseFoodMappings {
                if variants.contains(lowercaseToken) {
                    return baseFood
                }
            }
        }
        
        // 如果没有找到匹配项，返回最长的名词作为核心名称
        if let longestNoun = nouns.max(by: { $0.count < $1.count }) {
            return longestNoun
        }
        
        // 最后返回去除形容词后的文本
        let filteredTokens = allTokens.filter { token in
            !adjectives.contains(token.lowercased()) && !quantifiers.contains(token.lowercased())
        }
        
        if filteredTokens.isEmpty {
            return text
        }
        
        // 对于中文文本，不使用空格连接
        let joinedText = filteredTokens.joined(separator: " ")
        return removeInternalSpacesFromChinese(joinedText)
    }
    
    /// 计算两个食物名称的相似度 (0.0 - 1.0)
    func calculateSimilarity(between name1: String, name2: String) -> Double {
        let baseName1 = getBaseFoodName(name1)
        let baseName2 = getBaseFoodName(name2)
        
        // 如果基础名称完全相同，相似度为1.0
        if baseName1.lowercased() == baseName2.lowercased() {
            return 1.0
        }
        
        // 检查是否属于同一个食物家族
        for (_, variants) in baseFoodMappings {
            if variants.contains(baseName1.lowercased()) && variants.contains(baseName2.lowercased()) {
                return 1.0
            }
        }
        
        // 使用编辑距离计算相似度
        let distance = levenshteinDistance(baseName1.lowercased(), baseName2.lowercased())
        let maxLength = max(baseName1.count, baseName2.count)
        
        if maxLength == 0 {
            return 1.0
        }
        
        let similarity = 1.0 - Double(distance) / Double(maxLength)
        
        // 设置相似度阈值为0.8，低于此值认为不是同类食物
        return similarity >= 0.8 ? similarity : 0.0
    }
    
    /// 计算两个字符串的编辑距离
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
    
    /// 判断两个食物是否应该归为一组
    func shouldGroup(_ foodName1: String, _ foodName2: String) -> Bool {
        return calculateSimilarity(between: foodName1, name2: foodName2) >= 0.8
    }
    
    /// 为一组食物生成统一的显示名称
    func generateGroupDisplayName(for items: [FoodItem]) -> String {
        guard !items.isEmpty else { return "" }
        
        // 获取所有基础名称
        let baseNames = items.map { getBaseFoodName($0.name) }
        
        // 找到最常见的基础名称
        let nameCounts = Dictionary(grouping: baseNames, by: { $0 }).mapValues { $0.count }
        let mostCommonBase = nameCounts.max(by: { $0.value < $1.value })?.key ?? baseNames.first!
        
        return mostCommonBase
    }
}