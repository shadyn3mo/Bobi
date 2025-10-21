import Foundation
import SwiftUI

enum StorageLocation: String, CaseIterable, Codable {
    case freezer = "Freezer"
    case refrigerator = "Refrigerator"
    case pantry = "Pantry"
    
    // 为数据迁移提供安全的解码
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let rawValue = try? container.decode(String.self),
           let location = StorageLocation(rawValue: rawValue) {
            self = location
        } else {
            // 如果解码失败，使用默认值
            self = .refrigerator
        }
    }
    
    var localizedName: String {
        switch self {
        case .freezer: return "storage.freezer".localized
        case .refrigerator: return "storage.refrigerator".localized
        case .pantry: return "storage.pantry".localized
        }
    }
    
    var icon: String {
        switch self {
        case .freezer: return "❄️"
        case .refrigerator: return "🧊"
        case .pantry: return "🏠"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .freezer: return "snowflake"
        case .refrigerator: return "refrigerator"
        case .pantry: return "house"
        }
    }
    
    var color: Color {
        switch self {
        case .freezer: return .cyan
        case .refrigerator: return .blue
        case .pantry: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .freezer: return "storage.freezer.description".localized
        case .refrigerator: return "storage.refrigerator.description".localized
        case .pantry: return "storage.pantry.description".localized
        }
    }
}

class StorageLocationRecommendationEngine {
    static let shared = StorageLocationRecommendationEngine()
    
    private init() {}
    
    func recommendStorageLocation(for foodName: String, category: FoodCategory) -> StorageLocation {
        let normalizedName = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let specificRecommendation = getSpecificFoodRecommendation(normalizedName) {
            return specificRecommendation
        }
        
        return getCategoryRecommendation(category)
    }
    
    func getShelfLifeDays(for foodName: String, category: FoodCategory, storageLocation: StorageLocation) -> Int {
        let normalizedName = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let specificShelfLife = getSpecificShelfLife(normalizedName, storageLocation: storageLocation) {
            return specificShelfLife
        }
        
        return getCategoryShelfLife(category, storageLocation: storageLocation)
    }
    
    private func getSpecificFoodRecommendation(_ foodName: String) -> StorageLocation? {
        let freezerFoods = [
            // 肉类 - 红肉
            "牛肉", "猪肉", "羊肉", "鹿肉", "兔肉", "牛排", "猪排", "羊排", "里脊", "肋排", "牛腩", "猪腩", "牛筋", "猪蹄", "牛尾", "猪尾",
            "beef", "pork", "lamb", "venison", "rabbit", "steak", "ribs", "tenderloin", "brisket", "hock", "tail",
            // 肉类 - 禽肉
            "鸡肉", "鸭肉", "鹅肉", "火鸡", "鹌鹑", "鸽子", "鸡腿", "鸡翅", "鸡胸肉", "鸭腿", "鸭胸", "鸡脖", "鸡爪", "鸭掌",
            "chicken", "duck", "goose", "turkey", "quail", "pigeon", "drumstick", "wing", "breast", "neck", "feet",
            // 肉类制品
            "肉丸", "香肠", "培根", "火腿", "腊肉", "咸肉", "肉松", "肉脯", "腌肉", "熏肉", "肉馅", "绞肉",
            "meatball", "sausage", "bacon", "ham", "jerky", "ground meat", "minced meat", "cured meat", "smoked meat",
            // 海鲜 - 鱼类
            "三文鱼", "金枪鱼", "鳕鱼", "鲈鱼", "带鱼", "黄鱼", "鲤鱼", "草鱼", "鲫鱼", "鳗鱼", "比目鱼", "鲽鱼", "石斑鱼", "马鲛鱼",
            "salmon", "tuna", "cod", "bass", "hairtail", "yellow croaker", "carp", "grass carp", "crucian carp", "eel", "flounder", "halibut", "grouper", "mackerel",
            // 海鲜 - 贝类甲壳类
            "虾", "蟹", "扇贝", "蛤蜊", "生蚝", "鱿鱼", "章鱼", "海参", "鲍鱼", "龙虾", "螃蟹", "海虾", "河虾", "基围虾", "白虾", "明虾",
            "shrimp", "crab", "scallop", "clam", "oyster", "squid", "octopus", "sea cucumber", "abalone", "lobster", "prawns",
            // 冷冻食品
            "冰淇淋", "雪糕", "汤圆", "饺子", "包子", "馄饨", "春卷", "锅贴", "烧饼", "速冻蔬菜", "冷冻水果", "冷冻浆果", "冰棒",
            "ice cream", "popsicle", "dumpling", "bun", "wonton", "spring roll", "frozen vegetables", "frozen fruit", "frozen berries", "ice pop"
        ]
        
        let refrigeratorFoods = [
            // 乳制品
            "牛奶", "酸奶", "奶酪", "黄油", "奶油", "芝士", "马苏里拉", "切达", "帕玛森", "布里", "羊奶", "椰奶", "杏仁奶", "豆奶", "酪乳",
            "milk", "yogurt", "cheese", "butter", "cream", "mozzarella", "cheddar", "parmesan", "brie", "goat milk", "coconut milk", "almond milk", "soy milk", "buttermilk",
            // 蛋类
            "鸡蛋", "鸭蛋", "鹅蛋", "鹌鹑蛋", "咸鸭蛋", "松花蛋", "茶叶蛋",
            "chicken egg", "duck egg", "goose egg", "quail egg", "salted egg", "preserved egg", "tea egg",
            // 新鲜蔬菜 - 叶菜类
            "白菜", "菠菜", "韭菜", "芹菜", "生菜", "油菜", "小白菜", "茼蒿", "苋菜", "空心菜", "菜心", "芥菜", "荠菜", "香菜", "香葱", "韭黄",
            "cabbage", "spinach", "leek", "celery", "lettuce", "bok choy", "chrysanthemum greens", "amaranth", "water spinach", "mustard greens", "cilantro", "scallion",
            // 新鲜蔬菜 - 根茎类
            "胡萝卜", "萝卜", "白萝卜", "红萝卜", "土豆", "红薯", "山药", "芋头", "莲藕", "竹笋", "生姜", "大蒜", "洋葱", "大葱",
            "carrot", "radish", "white radish", "potato", "sweet potato", "yam", "taro", "lotus root", "bamboo shoot", "ginger", "garlic", "onion",
            // 新鲜蔬菜 - 瓜果类
            "茄子", "豆角", "黄瓜", "西红柿", "青椒", "辣椒", "甜椒", "彩椒", "花菜", "西兰花", "卷心菜", "紫甘蓝", "冬瓜", "丝瓜", "苦瓜", "南瓜",
            "eggplant", "green bean", "cucumber", "tomato", "pepper", "bell pepper", "cauliflower", "broccoli", "winter melon", "bitter melon", "pumpkin",
            // 新鲜蔬菜 - 菌菇类
            "蘑菇", "香菇", "平菇", "金针菇", "杏鲍菇", "茶树菇", "口蘑", "草菇", "猴头菇", "木耳", "银耳",
            "mushroom", "shiitake", "oyster mushroom", "enoki", "king oyster mushroom", "tea tree mushroom", "wood ear", "white fungus",
            // 🧊 冰箱保存水果（冷藏区售卖，需要冷藏保鲜）
            "草莓", "蓝莓", "黑莓", "覆盆子", "蔓越莓", "桑葚", "樱桃", "葡萄", "提子",
            "strawberry", "blueberry", "blackberry", "raspberry", "cranberry", "mulberry", "cherry", "grape",
            // 切开的水果（必须冷藏）
            "切开的西瓜", "切好的菠萝", "切好的芒果", "熟奇异果", "切开的香蕉",
            "cut watermelon", "cut pineapple", "cut mango", "ripe kiwi", "cut banana",
            // 特殊冷藏水果
            "哈密瓜", "香瓜", "甜瓜", "龙眼", "荔枝", "火龙果", "百香果",
            "cantaloupe", "honeydew", "longan", "lychee", "dragon fruit", "passion fruit",
            // 豆类制品
            "豆腐", "豆干", "豆皮", "腐竹", "豆芽", "绿豆芽", "黄豆芽",
            "tofu", "dried tofu", "tofu skin", "bean sprouts", "mung bean sprouts", "soybean sprouts",
            // 调料酱料（需冷藏）
            "蒜泥", "姜泥", "辣椒酱", "沙拉酱", "蛋黄酱", "番茄酱", "芥末酱", "千岛酱", "蚝油", "鱼露", "韩式辣椒酱", "味噌",
            "garlic paste", "ginger paste", "chili sauce", "salad dressing", "mayonnaise", "ketchup", "mustard", "thousand island", "oyster sauce", "fish sauce", "miso"
        ]
        
        let pantryFoods = [
            // 谷物主食
            "大米", "小米", "黑米", "糯米", "香米", "泰香米", "面粉", "全麦粉", "玉米粉", "小麦", "大麦", "燕麦", "藜麦", "荞麦", "高粱",
            "rice", "millet", "black rice", "glutinous rice", "jasmine rice", "flour", "whole wheat flour", "corn flour", "wheat", "barley", "oats", "quinoa", "buckwheat", "sorghum",
            // 面食制品
            "面条", "挂面", "意大利面", "通心粉", "拉面", "乌冬面", "荞麦面", "米粉", "粉丝", "粉条", "凉皮", "河粉",
            "noodles", "pasta", "macaroni", "ramen", "udon", "soba", "rice noodles", "vermicelli", "glass noodles",
            // 豆类干货
            "绿豆", "红豆", "黑豆", "黄豆", "白豆", "芸豆", "蚕豆", "豌豆", "扁豆", "花豆", "鹰嘴豆", "红腰豆",
            "mung bean", "red bean", "black bean", "soybean", "white bean", "kidney bean", "broad bean", "pea", "lentil", "chickpea",
            // 坚果类
            "花生", "核桃", "杏仁", "腰果", "开心果", "榛子", "松子", "栗子", "白果", "夏威夷果", "碧根果", "巴旦木",
            "peanut", "walnut", "almond", "cashew", "pistachio", "hazelnut", "pine nut", "chestnut", "ginkgo", "macadamia", "pecan",
            // 干果蜜饯
            "葡萄干", "大枣", "红枣", "蜜枣", "桂圆", "枸杞", "无花果干", "杏干", "柿饼", "山楂片", "话梅", "蜜饯",
            "raisin", "jujube", "dried date", "dried fig", "dried apricot", "persimmon cake", "preserved plum", "dried fruit",
            // 罐头食品
            "午餐肉", "金枪鱼罐头", "沙丁鱼罐头", "玉米罐头", "豌豆罐头", "番茄罐头", "桃子罐头", "黄桃罐头", "橘子罐头", "椰奶罐头",
            "spam", "canned tuna", "canned sardines", "canned corn", "canned peas", "canned tomato", "canned peach", "canned mandarin", "canned coconut milk",
            // 调料香料
            "盐", "糖", "冰糖", "红糖", "蜂蜜", "枫糖", "胡椒粉", "黑胡椒", "白胡椒", "辣椒粉", "花椒", "孜然", "八角", "桂皮", "丁香", "肉桂",
            "salt", "sugar", "rock sugar", "brown sugar", "honey", "maple syrup", "pepper", "black pepper", "white pepper", "chili powder", "sichuan pepper", "cumin", "star anise", "cinnamon", "clove",
            // 调味品
            "生抽", "老抽", "醋", "白醋", "香醋", "料酒", "黄酒", "米酒", "香油", "芝麻油", "橄榄油", "植物油", "花生油", "菜籽油", "玉米油",
            "soy sauce", "dark soy sauce", "vinegar", "white vinegar", "rice wine", "sesame oil", "olive oil", "vegetable oil", "peanut oil", "canola oil", "corn oil",
            // 酱料腌菜
            "豆豉", "豆瓣酱", "甜面酱", "海鲜酱", "腐乳", "咸菜", "酱菜", "泡菜", "榨菜", "萝卜干", "梅干菜",
            "fermented black beans", "bean paste", "sweet bean sauce", "seafood sauce", "fermented tofu", "pickled vegetables", "preserved mustard greens",
            // 🌡 常温保存的水果（常温货架售卖，可冷藏延长保质期）
            "苹果", "梨", "橘子", "桔子", "橙子", "柠檬", "柚子", "金桔", "柑", "青柠",
            "西瓜", "芒果", "猕猴桃", "奇异果", "桃子", "牛油果", "番茄", "香蕉",
            "李子", "杏", "石榴", "无花果", "山楂", "柿子", "番石榴",
            "apple", "pear", "orange", "mandarin", "tangerine", "lemon", "grapefruit", "kumquat", "lime",
            "watermelon", "mango", "kiwi", "peach", "avocado", "tomato", "banana",
            "plum", "apricot", "pomegranate", "fig", "hawthorn", "persimmon", "guava",
            // 零食饼干
            "饼干", "曲奇", "薯片", "爆米花", "瓜子", "葵花籽", "南瓜子", "西瓜子", "花生米", "巧克力", "糖果", "软糖", "硬糖", "棒棒糖",
            "biscuit", "cookie", "chips", "popcorn", "sunflower seeds", "pumpkin seeds", "watermelon seeds", "chocolate", "candy", "gummy", "hard candy", "lollipop",
            // 茶叶饮品
            "茶叶", "绿茶", "红茶", "乌龙茶", "普洱茶", "花茶", "咖啡豆", "咖啡粉", "速溶咖啡", "可可粉",
            "tea", "green tea", "black tea", "oolong tea", "pu-erh tea", "flower tea", "coffee beans", "coffee powder", "instant coffee", "cocoa powder"
        ]
        
        for food in freezerFoods {
            if foodName.contains(food) {
                return .freezer
            }
        }
        
        for food in refrigeratorFoods {
            if foodName.contains(food) {
                return .refrigerator
            }
        }
        
        for food in pantryFoods {
            if foodName.contains(food) {
                return .pantry
            }
        }
        
        // 特殊处理：不适合冷藏的水果默认推荐储物室
        let roomTemperatureFruits = ["香蕉", "牛油果", "柿子", "番石榴", "banana", "avocado", "persimmon", "guava"]
        for fruit in roomTemperatureFruits {
            if foodName.contains(fruit) {
                return .pantry
            }
        }
        
        return nil
    }
    
    private func getCategoryRecommendation(_ category: FoodCategory) -> StorageLocation {
        switch category {
        case .meat, .seafood, .frozen:
            return .freezer
        case .dairy, .eggs, .vegetables, .fruits:
            return .refrigerator
        case .grains, .condiments, .canned, .snacks, .other:
            return .pantry
        case .beverages:
            return .refrigerator
        }
    }
    
    private func getSpecificShelfLife(_ foodName: String, storageLocation: StorageLocation) -> Int? {
        let shelfLifeDatabase: [String: [StorageLocation: Int]] = [
            // 肉类 - 红肉 (基于2024-2025最新食品安全标准)
            "牛肉": [.freezer: 315, .refrigerator: 4, .pantry: 1],
            "猪肉": [.freezer: 270, .refrigerator: 4, .pantry: 1],
            "羊肉": [.freezer: 315, .refrigerator: 4, .pantry: 1],
            "牛排": [.freezer: 315, .refrigerator: 4, .pantry: 1],
            "猪排": [.freezer: 270, .refrigerator: 4, .pantry: 1],
            "beef": [.freezer: 315, .refrigerator: 4, .pantry: 1],
            "pork": [.freezer: 270, .refrigerator: 4, .pantry: 1],
            "lamb": [.freezer: 315, .refrigerator: 4, .pantry: 1],
            "steak": [.freezer: 315, .refrigerator: 4, .pantry: 1],
            
            // 肉类 - 禽肉
            "鸡肉": [.freezer: 365, .refrigerator: 2, .pantry: 1],
            "鸭肉": [.freezer: 180, .refrigerator: 2, .pantry: 1],
            "鸡腿": [.freezer: 270, .refrigerator: 2, .pantry: 1],
            "鸡翅": [.freezer: 270, .refrigerator: 2, .pantry: 1],
            "鸡胸肉": [.freezer: 270, .refrigerator: 2, .pantry: 1],
            "chicken": [.freezer: 365, .refrigerator: 2, .pantry: 1],
            "duck": [.freezer: 180, .refrigerator: 2, .pantry: 1],
            "turkey": [.freezer: 365, .refrigerator: 2, .pantry: 1],
            
            // 肉类制品
            "香肠": [.freezer: 45, .refrigerator: 7, .pantry: 1],
            "培根": [.freezer: 30, .refrigerator: 7, .pantry: 1],
            "火腿": [.freezer: 45, .refrigerator: 21, .pantry: 7],
            "肉丸": [.freezer: 105, .refrigerator: 2, .pantry: 1],
            "sausage": [.freezer: 45, .refrigerator: 7, .pantry: 1],
            "bacon": [.freezer: 30, .refrigerator: 7, .pantry: 1],
            "ham": [.freezer: 45, .refrigerator: 21, .pantry: 7],
            
            // 海鲜 - 鱼类
            "三文鱼": [.freezer: 75, .refrigerator: 2, .pantry: 1],
            "金枪鱼": [.freezer: 210, .refrigerator: 2, .pantry: 1],
            "鳕鱼": [.freezer: 210, .refrigerator: 2, .pantry: 1],
            "鲈鱼": [.freezer: 210, .refrigerator: 2, .pantry: 1],
            "鱼肉": [.freezer: 180, .refrigerator: 2, .pantry: 1],
            "salmon": [.freezer: 75, .refrigerator: 2, .pantry: 1],
            "tuna": [.freezer: 210, .refrigerator: 2, .pantry: 1],
            "cod": [.freezer: 210, .refrigerator: 2, .pantry: 1],
            "fish": [.freezer: 180, .refrigerator: 2, .pantry: 1],
            
            // 海鲜 - 贝类甲壳类
            "虾": [.freezer: 150, .refrigerator: 2, .pantry: 1],
            "蟹": [.freezer: 90, .refrigerator: 2, .pantry: 1],
            "扇贝": [.freezer: 90, .refrigerator: 2, .pantry: 1],
            "蛤蜊": [.freezer: 75, .refrigerator: 2, .pantry: 1],
            "生蚝": [.freezer: 75, .refrigerator: 2, .pantry: 1],
            "鱿鱼": [.freezer: 90, .refrigerator: 2, .pantry: 1],
            "shrimp": [.freezer: 150, .refrigerator: 2, .pantry: 1],
            "crab": [.freezer: 90, .refrigerator: 2, .pantry: 1],
            "scallop": [.freezer: 90, .refrigerator: 2, .pantry: 1],
            "oyster": [.freezer: 75, .refrigerator: 2, .pantry: 1],
            "squid": [.freezer: 90, .refrigerator: 2, .pantry: 1],
            
            // 乳制品
            "牛奶": [.freezer: 90, .refrigerator: 6, .pantry: 0],
            "酸奶": [.freezer: 45, .refrigerator: 10, .pantry: 0],
            "奶酪": [.freezer: 180, .refrigerator: 25, .pantry: 0],
            "黄油": [.freezer: 225, .refrigerator: 60, .pantry: 1],
            "奶油": [.freezer: 180, .refrigerator: 21, .pantry: 0],
            "芝士": [.freezer: 180, .refrigerator: 25, .pantry: 0],
            "milk": [.freezer: 90, .refrigerator: 6, .pantry: 0],
            "yogurt": [.freezer: 45, .refrigerator: 10, .pantry: 0],
            "cheese": [.freezer: 180, .refrigerator: 25, .pantry: 0],
            "butter": [.freezer: 225, .refrigerator: 60, .pantry: 1],
            "cream": [.freezer: 180, .refrigerator: 21, .pantry: 0],
            
            // 蛋类
            "鸡蛋": [.freezer: 0, .refrigerator: 28, .pantry: 7],
            "鸭蛋": [.freezer: 0, .refrigerator: 28, .pantry: 7],
            "鹌鹑蛋": [.freezer: 0, .refrigerator: 28, .pantry: 7],
            "egg": [.freezer: 0, .refrigerator: 28, .pantry: 7],
            
            // 新鲜蔬菜 - 叶菜类
            "白菜": [.freezer: 180, .refrigerator: 7, .pantry: 2],
            "菠菜": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "韭菜": [.freezer: 180, .refrigerator: 3, .pantry: 1],
            "芹菜": [.freezer: 180, .refrigerator: 7, .pantry: 2],
            "生菜": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "油菜": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "cabbage": [.freezer: 180, .refrigerator: 7, .pantry: 2],
            "spinach": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "lettuce": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "celery": [.freezer: 180, .refrigerator: 7, .pantry: 2],
            
            // 新鲜蔬菜 - 根茎类
            "胡萝卜": [.freezer: 365, .refrigerator: 21, .pantry: 7],
            "萝卜": [.freezer: 365, .refrigerator: 14, .pantry: 5],
            "土豆": [.freezer: 365, .refrigerator: 30, .pantry: 60],
            "红薯": [.freezer: 365, .refrigerator: 14, .pantry: 30],
            "洋葱": [.freezer: 365, .refrigerator: 30, .pantry: 90],
            "大蒜": [.freezer: 365, .refrigerator: 30, .pantry: 180],
            "生姜": [.freezer: 365, .refrigerator: 21, .pantry: 14],
            "carrot": [.freezer: 365, .refrigerator: 21, .pantry: 7],
            "potato": [.freezer: 365, .refrigerator: 30, .pantry: 60],
            "onion": [.freezer: 365, .refrigerator: 30, .pantry: 90],
            "garlic": [.freezer: 365, .refrigerator: 30, .pantry: 180],
            "ginger": [.freezer: 365, .refrigerator: 21, .pantry: 14],
            
            // 新鲜蔬菜 - 瓜果类
            "茄子": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "豆角": [.freezer: 365, .refrigerator: 5, .pantry: 2],
            "黄瓜": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "西红柿": [.freezer: 180, .refrigerator: 7, .pantry: 5],
            "青椒": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "花菜": [.freezer: 365, .refrigerator: 7, .pantry: 2],
            "西兰花": [.freezer: 365, .refrigerator: 7, .pantry: 2],
            "eggplant": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "cucumber": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "pepper": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "cauliflower": [.freezer: 365, .refrigerator: 7, .pantry: 2],
            "broccoli": [.freezer: 365, .refrigerator: 7, .pantry: 2],
            
            // 菌菇类
            "蘑菇": [.freezer: 0, .refrigerator: 7, .pantry: 0],
            "香菇": [.freezer: 0, .refrigerator: 10, .pantry: 0],
            "金针菇": [.freezer: 0, .refrigerator: 7, .pantry: 0],
            "mushroom": [.freezer: 0, .refrigerator: 7, .pantry: 0],
            "shiitake": [.freezer: 0, .refrigerator: 10, .pantry: 0],
            
            // 🧊 冰箱保存水果（需要冷藏，常温保质期很短）
            "草莓": [.freezer: 300, .refrigerator: 3, .pantry: 1],
            "蓝莓": [.freezer: 300, .refrigerator: 5, .pantry: 1],
            "樱桃": [.freezer: 300, .refrigerator: 4, .pantry: 1],
            "葡萄": [.freezer: 300, .refrigerator: 7, .pantry: 2],
            "strawberry": [.freezer: 300, .refrigerator: 3, .pantry: 1],
            "blueberry": [.freezer: 300, .refrigerator: 5, .pantry: 1],
            "cherry": [.freezer: 300, .refrigerator: 4, .pantry: 1],
            "grape": [.freezer: 300, .refrigerator: 7, .pantry: 2],
            
            // 🌡 常温保存水果（常温货架售卖，可冷藏延长保质期）
            "苹果": [.freezer: 365, .refrigerator: 30, .pantry: 14],
            "梨": [.freezer: 365, .refrigerator: 21, .pantry: 7],
            "桃子": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "李子": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "apple": [.freezer: 365, .refrigerator: 30, .pantry: 14],
            "pear": [.freezer: 365, .refrigerator: 21, .pantry: 7],
            "peach": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "plum": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            
            // 柑橘类水果（常温保存，保质期长）
            "橙子": [.freezer: 365, .refrigerator: 21, .pantry: 14],
            "橘子": [.freezer: 365, .refrigerator: 14, .pantry: 10],
            "柠檬": [.freezer: 365, .refrigerator: 30, .pantry: 21],
            "柚子": [.freezer: 365, .refrigerator: 21, .pantry: 14],
            "orange": [.freezer: 365, .refrigerator: 21, .pantry: 14],
            "mandarin": [.freezer: 365, .refrigerator: 14, .pantry: 10],
            "lemon": [.freezer: 365, .refrigerator: 30, .pantry: 21],
            "grapefruit": [.freezer: 365, .refrigerator: 21, .pantry: 14],
            
            // 热带水果（常温保存，成熟后可冷藏）
            "芒果": [.freezer: 365, .refrigerator: 7, .pantry: 7],
            "西瓜": [.freezer: 365, .refrigerator: 7, .pantry: 7],
            "猕猴桃": [.freezer: 365, .refrigerator: 14, .pantry: 7],
            "奇异果": [.freezer: 365, .refrigerator: 14, .pantry: 7],
            "牛油果": [.freezer: 365, .refrigerator: 5, .pantry: 5],
            "番茄": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "香蕉": [.freezer: 365, .refrigerator: 7, .pantry: 7],
            "mango": [.freezer: 365, .refrigerator: 7, .pantry: 7],
            "watermelon": [.freezer: 365, .refrigerator: 7, .pantry: 7],
            "kiwi": [.freezer: 365, .refrigerator: 14, .pantry: 7],
            "avocado": [.freezer: 365, .refrigerator: 5, .pantry: 5],
            "tomato": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "banana": [.freezer: 365, .refrigerator: 7, .pantry: 7],
            
            // 其他常温水果
            "柿子": [.freezer: 180, .refrigerator: 7, .pantry: 10],
            "番石榴": [.freezer: 180, .refrigerator: 7, .pantry: 7],
            "石榴": [.freezer: 365, .refrigerator: 14, .pantry: 10],
            "无花果": [.freezer: 365, .refrigerator: 5, .pantry: 3],
            "persimmon": [.freezer: 180, .refrigerator: 7, .pantry: 10],
            "guava": [.freezer: 180, .refrigerator: 7, .pantry: 7],
            "pomegranate": [.freezer: 365, .refrigerator: 14, .pantry: 10],
            "fig": [.freezer: 365, .refrigerator: 5, .pantry: 3],
            
            // 切开的水果（必须冷藏，常温易坏）
            "切开的西瓜": [.freezer: 180, .refrigerator: 2, .pantry: 1],
            "切好的菠萝": [.freezer: 180, .refrigerator: 3, .pantry: 1],
            "切好的芒果": [.freezer: 180, .refrigerator: 3, .pantry: 1],
            "熟奇异果": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "切开的香蕉": [.freezer: 90, .refrigerator: 1, .pantry: 1],
            "cut watermelon": [.freezer: 180, .refrigerator: 2, .pantry: 1],
            "cut pineapple": [.freezer: 180, .refrigerator: 3, .pantry: 1],
            "cut mango": [.freezer: 180, .refrigerator: 3, .pantry: 1],
            "ripe kiwi": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "cut banana": [.freezer: 90, .refrigerator: 1, .pantry: 1],
            
            // 特殊冷藏水果（成熟后需冷藏）
            "菠萝": [.freezer: 365, .refrigerator: 5, .pantry: 3],
            "哈密瓜": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "香瓜": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "甜瓜": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "龙眼": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "荔枝": [.freezer: 365, .refrigerator: 5, .pantry: 2],
            "火龙果": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "百香果": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "pineapple": [.freezer: 365, .refrigerator: 5, .pantry: 3],
            "cantaloupe": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "honeydew": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "longan": [.freezer: 365, .refrigerator: 7, .pantry: 3],
            "lychee": [.freezer: 365, .refrigerator: 5, .pantry: 2],
            "dragon fruit": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            "passion fruit": [.freezer: 365, .refrigerator: 7, .pantry: 5],
            
            // 豆类制品
            "豆腐": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            "豆干": [.freezer: 180, .refrigerator: 14, .pantry: 3],
            "豆芽": [.freezer: 180, .refrigerator: 3, .pantry: 1],
            "tofu": [.freezer: 180, .refrigerator: 5, .pantry: 1],
            
            // 谷物主食
            "大米": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "面粉": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "燕麦": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "小米": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "藜麦": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "rice": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "flour": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "oats": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "quinoa": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            
            // 面食制品
            "面条": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "意大利面": [.freezer: 365, .refrigerator: 180, .pantry: 730],
            "noodles": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "pasta": [.freezer: 365, .refrigerator: 180, .pantry: 730],
            
            // 豆类干货
            "绿豆": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "红豆": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "黄豆": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "花生": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "核桃": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "杏仁": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            
            // 调料香料
            "盐": [.freezer: 3650, .refrigerator: 3650, .pantry: 3650],
            "糖": [.freezer: 1825, .refrigerator: 1825, .pantry: 1825],
            "蜂蜜": [.freezer: 1825, .refrigerator: 1825, .pantry: 1825],
            "醋": [.freezer: 1825, .refrigerator: 1825, .pantry: 1825],
            "香油": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "橄榄油": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            "salt": [.freezer: 3650, .refrigerator: 3650, .pantry: 3650],
            "sugar": [.freezer: 1825, .refrigerator: 1825, .pantry: 1825],
            "honey": [.freezer: 1825, .refrigerator: 1825, .pantry: 1825],
            "vinegar": [.freezer: 1825, .refrigerator: 1825, .pantry: 1825],
            "olive oil": [.freezer: 730, .refrigerator: 365, .pantry: 365],
            
            // 罐头食品
            "午餐肉": [.freezer: 1095, .refrigerator: 1095, .pantry: 1095],
            "金枪鱼罐头": [.freezer: 1095, .refrigerator: 1095, .pantry: 1095],
            "玉米罐头": [.freezer: 730, .refrigerator: 730, .pantry: 730],
            "spam": [.freezer: 1095, .refrigerator: 1095, .pantry: 1095],
            "canned tuna": [.freezer: 1095, .refrigerator: 1095, .pantry: 1095],
            
            // 零食
            "饼干": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "薯片": [.freezer: 365, .refrigerator: 90, .pantry: 90],
            "巧克力": [.freezer: 365, .refrigerator: 180, .pantry: 90],
            "biscuit": [.freezer: 365, .refrigerator: 180, .pantry: 180],
            "chips": [.freezer: 365, .refrigerator: 90, .pantry: 90],
            "chocolate": [.freezer: 365, .refrigerator: 180, .pantry: 90]
        ]
        
        for (food, shelfLife) in shelfLifeDatabase {
            if foodName.contains(food) {
                return shelfLife[storageLocation]
            }
        }
        
        return nil
    }
    
    private func getCategoryShelfLife(_ category: FoodCategory, storageLocation: StorageLocation) -> Int {
        switch (category, storageLocation) {
        case (.meat, .freezer): return 270
        case (.meat, .refrigerator): return 3
        case (.meat, .pantry): return 1
        
        case (.seafood, .freezer): return 150
        case (.seafood, .refrigerator): return 2
        case (.seafood, .pantry): return 1
        
        case (.dairy, .freezer): return 120
        case (.dairy, .refrigerator): return 7
        case (.dairy, .pantry): return 0
        
        case (.eggs, .freezer): return 0
        case (.eggs, .refrigerator): return 28
        case (.eggs, .pantry): return 7
        
        case (.vegetables, .freezer): return 0
        case (.vegetables, .refrigerator): return 5
        case (.vegetables, .pantry): return 2
        
        case (.fruits, .freezer): return 240
        case (.fruits, .refrigerator): return 7
        case (.fruits, .pantry): return 3
        
        case (.grains, .freezer): return 0
        case (.grains, .refrigerator): return 0
        case (.grains, .pantry): return 365
        
        case (.beverages, .freezer): return 90
        case (.beverages, .refrigerator): return 7
        case (.beverages, .pantry): return 14
        
        case (.condiments, .freezer): return 0
        case (.condiments, .refrigerator): return 180
        case (.condiments, .pantry): return 730
        
        case (.frozen, .freezer): return 180
        case (.frozen, .refrigerator): return 1
        case (.frozen, .pantry): return 1
        
        case (.canned, .freezer): return 0
        case (.canned, .refrigerator): return 0
        case (.canned, .pantry): return 1095
        
        case (.snacks, .freezer): return 0
        case (.snacks, .refrigerator): return 0
        case (.snacks, .pantry): return 120
        
        case (.other, .freezer): return 180
        case (.other, .refrigerator): return 7
        case (.other, .pantry): return 30
        }
    }
}