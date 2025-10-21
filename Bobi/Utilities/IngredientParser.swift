import Foundation
import SwiftData

// MARK: - 食材解析和分类工具类
struct IngredientParser {
    
    /// 解析带数量的食材字符串，返回 (名称, 数量, 单位)
    static func parseIngredientWithQuantity(_ ingredient: String) -> (String, Int, String) {
        let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 使用正则表达式匹配 "食材名 数量单位" 格式，如 "鸡蛋 2个", "面条 200g"
        let regex = try? NSRegularExpression(pattern: "^(.+?)\\s+(\\d+)(\\w+)$", options: [])
        let nsString = trimmed as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        if let match = regex?.firstMatch(in: trimmed, options: [], range: range) {
            let nameRange = match.range(at: 1)
            let quantityRange = match.range(at: 2)
            let unitRange = match.range(at: 3)
            
            if nameRange.location != NSNotFound && quantityRange.location != NSNotFound && unitRange.location != NSNotFound {
                let name = nsString.substring(with: nameRange).trimmingCharacters(in: .whitespacesAndNewlines)
                let quantityStr = nsString.substring(with: quantityRange)
                let unit = nsString.substring(with: unitRange)
                
                if let quantity = Int(quantityStr) {
                    return (name, quantity, unit)
                }
            }
        }
        
        // 如果解析失败，尝试简单的分割方式
        let components = trimmed.components(separatedBy: " ")
        if components.count >= 2 {
            let name = components[0]
            let lastComponent = components.last!
            
            // 检查最后一个组件是否包含数字
            let numberRegex = try? NSRegularExpression(pattern: "\\d+", options: [])
            if let _ = numberRegex?.firstMatch(in: lastComponent, options: [], range: NSRange(location: 0, length: lastComponent.count)) {
                // 如果包含数字，尝试分离数字和单位
                let digitRegex = try? NSRegularExpression(pattern: "(\\d+)(.*)", options: [])
                if let match = digitRegex?.firstMatch(in: lastComponent, options: [], range: NSRange(location: 0, length: lastComponent.count)) {
                    let quantityRange = match.range(at: 1)
                    let unitRange = match.range(at: 2)
                    
                    if quantityRange.location != NSNotFound {
                        let quantityStr = (lastComponent as NSString).substring(with: quantityRange)
                        let unit = unitRange.location != NSNotFound ? (lastComponent as NSString).substring(with: unitRange) : ""
                        
                        if let quantity = Int(quantityStr) {
                            return (name, quantity, unit)
                        }
                    }
                }
            }
        }
        
        // 完全解析失败，返回食材名和默认值
        return (trimmed, 1, FoodItem.defaultUnit)
    }
    
    /// 检查是否为调料或基础调味品
    static func isCondimentOrBasicSeasoning(_ ingredient: String) -> Bool {
        let lowercased = ingredient.lowercased()
        
        // 基础调料
        let basicSeasonings = [
            "盐", "salt", "糖", "sugar", "油", "oil", "生抽", "老抽", "醋", "vinegar",
            "料酒", "胡椒", "pepper", "花椒", "五香粉", "鸡精", "味精", "蚝油",
            "香油", "sesame oil", "芝麻油", "生姜", "ginger", "大蒜", "garlic",
            "葱花", "scallion", "香菜", "cilantro", "孜然", "八角", "桂皮"
        ]
        
        return basicSeasonings.contains { seasoning in
            lowercased.contains(seasoning) || lowercased == seasoning
        }
    }
    
    /// 根据食材名称猜测类别
    static func guessIngredientCategory(_ ingredient: String) -> FoodCategory {
        let lowercased = ingredient.lowercased()
        
        // 蛋类 - 优先判断，避免被肉类误判
        if lowercased.contains("蛋") || lowercased.contains("egg") || lowercased == "鸡蛋" || lowercased == "eggs" ||
           lowercased.contains("鸭蛋") || lowercased.contains("鹌鹑蛋") || lowercased.contains("咸鸭蛋") ||
           lowercased.contains("皮蛋") || lowercased.contains("松花蛋") {
            return .eggs
        }
        
        // 蔬菜 - 包含番茄等
        if lowercased.contains("番茄") || lowercased.contains("tomato") || lowercased.contains("西红柿") ||
           lowercased.contains("菜") || lowercased.contains("萝卜") || lowercased.contains("白菜") ||
           lowercased.contains("菠菜") || lowercased.contains("芹菜") || lowercased.contains("韭菜") ||
           lowercased.contains("lettuce") || lowercased.contains("spinach") || lowercased.contains("carrot") ||
           lowercased.contains("onion") || lowercased.contains("garlic") || lowercased.contains("蒜") ||
           lowercased.contains("葱") || lowercased.contains("姜") || lowercased.contains("ginger") ||
           lowercased.contains("青椒") || lowercased.contains("辣椒") || lowercased.contains("pepper") ||
           lowercased.contains("洋葱") || lowercased.contains("土豆") || lowercased.contains("potato") ||
           lowercased.contains("茄子") || lowercased.contains("eggplant") || lowercased.contains("黄瓜") ||
           lowercased.contains("cucumber") || lowercased.contains("豆芽") || lowercased.contains("豆腐") ||
           lowercased.contains("tofu") || lowercased.contains("西兰花") || lowercased.contains("broccoli") ||
           lowercased.contains("花菜") || lowercased.contains("cauliflower") || lowercased.contains("包菜") ||
           lowercased.contains("卷心菜") || lowercased.contains("cabbage") || lowercased.contains("冬瓜") ||
           lowercased.contains("南瓜") || lowercased.contains("pumpkin") || lowercased.contains("丝瓜") ||
           lowercased.contains("苦瓜") || lowercased.contains("青瓜") || lowercased.contains("胡萝卜") ||
           lowercased.contains("红萝卜") || lowercased.contains("莲藕") || lowercased.contains("芋头") ||
           lowercased.contains("山药") || lowercased.contains("红薯") || lowercased.contains("sweet potato") ||
           lowercased.contains("蘑菇") || lowercased.contains("mushroom") || lowercased.contains("香菇") ||
           lowercased.contains("金针菇") || lowercased.contains("平菇") || lowercased.contains("木耳") ||
           lowercased.contains("豆角") || lowercased.contains("四季豆") || lowercased.contains("green beans") ||
           lowercased.contains("豌豆") || lowercased.contains("peas") || lowercased.contains("玉米") ||
           lowercased.contains("corn") || lowercased.contains("竹笋") || lowercased.contains("bamboo") {
            return .vegetables
        }
        
        // 肉类 - 排除鸡蛋
        if (lowercased.contains("肉") || lowercased.contains("beef") || lowercased.contains("pork") ||
           lowercased.contains("chicken") || lowercased.contains("lamb") || lowercased.contains("牛") ||
           lowercased.contains("猪") || lowercased.contains("羊") || lowercased.contains("鸡") ||
           lowercased.contains("鸭") || lowercased.contains("duck") || lowercased.contains("鹅") ||
           lowercased.contains("goose") || lowercased.contains("火腿") || lowercased.contains("ham") ||
           lowercased.contains("香肠") || lowercased.contains("sausage") || lowercased.contains("培根") ||
           lowercased.contains("bacon") || lowercased.contains("鸡胸") || lowercased.contains("鸡腿") ||
           lowercased.contains("chicken breast") || lowercased.contains("chicken thigh") ||
           lowercased.contains("牛排") || lowercased.contains("steak") || lowercased.contains("里脊") ||
           lowercased.contains("tenderloin") || lowercased.contains("排骨") || lowercased.contains("ribs")) && !lowercased.contains("蛋") {
            return .meat
        }
        
        // 海鲜
        if lowercased.contains("鱼") || lowercased.contains("虾") || lowercased.contains("蟹") ||
           lowercased.contains("fish") || lowercased.contains("shrimp") || lowercased.contains("crab") ||
           lowercased.contains("salmon") || lowercased.contains("tuna") || lowercased.contains("带鱼") ||
           lowercased.contains("黄鱼") || lowercased.contains("鲈鱼") || lowercased.contains("草鱼") ||
           lowercased.contains("鲤鱼") || lowercased.contains("鲫鱼") || lowercased.contains("cod") ||
           lowercased.contains("鳕鱼") || lowercased.contains("秋刀鱼") || lowercased.contains("saury") ||
           lowercased.contains("龙虾") || lowercased.contains("lobster") || lowercased.contains("大虾") ||
           lowercased.contains("基围虾") || lowercased.contains("prawns") || lowercased.contains("扇贝") ||
           lowercased.contains("scallop") || lowercased.contains("蛤蜊") || lowercased.contains("clams") ||
           lowercased.contains("牡蛎") || lowercased.contains("oyster") || lowercased.contains("鱿鱼") ||
           lowercased.contains("squid") || lowercased.contains("章鱼") || lowercased.contains("octopus") ||
           lowercased.contains("海带") || lowercased.contains("seaweed") || lowercased.contains("紫菜") ||
           lowercased.contains("nori") {
            return .seafood
        }
        
        // 水果
        if lowercased.contains("果") || lowercased.contains("苹果") || lowercased.contains("香蕉") ||
           lowercased.contains("橙") || lowercased.contains("草莓") || lowercased.contains("蓝莓") ||
           lowercased.contains("apple") || lowercased.contains("banana") || lowercased.contains("orange") ||
           lowercased.contains("grape") || lowercased.contains("strawberry") || lowercased.contains("blueberry") ||
           lowercased.contains("berry") || lowercased.contains("梨") || lowercased.contains("pear") ||
           lowercased.contains("桃") || lowercased.contains("peach") || lowercased.contains("李子") ||
           lowercased.contains("plum") || lowercased.contains("樱桃") || lowercased.contains("cherry") ||
           lowercased.contains("葡萄") || lowercased.contains("西瓜") || lowercased.contains("watermelon") ||
           lowercased.contains("哈密瓜") || lowercased.contains("honeydew") || lowercased.contains("甜瓜") ||
           lowercased.contains("melon") || lowercased.contains("柠檬") || lowercased.contains("lemon") ||
           lowercased.contains("柚子") || lowercased.contains("grapefruit") || lowercased.contains("橘子") ||
           lowercased.contains("mandarin") || lowercased.contains("猕猴桃") || lowercased.contains("kiwi") ||
           lowercased.contains("芒果") || lowercased.contains("mango") || lowercased.contains("菠萝") ||
           lowercased.contains("pineapple") || lowercased.contains("荔枝") || lowercased.contains("lychee") ||
           lowercased.contains("龙眼") || lowercased.contains("longan") || lowercased.contains("榴莲") ||
           lowercased.contains("durian") || lowercased.contains("火龙果") || lowercased.contains("dragon fruit") ||
           lowercased.contains("椰子") || lowercased.contains("coconut") || lowercased.contains("枣") ||
           lowercased.contains("dates") || lowercased.contains("柿子") || lowercased.contains("persimmon") ||
           lowercased.contains("石榴") || lowercased.contains("pomegranate") {
            return .fruits
        }
        
        // 乳制品
        if lowercased.contains("奶") || lowercased.contains("酸奶") || lowercased.contains("奶酪") ||
           lowercased.contains("milk") || lowercased.contains("yogurt") || lowercased.contains("cheese") ||
           lowercased.contains("cream") || lowercased.contains("牛奶") || lowercased.contains("羊奶") ||
           lowercased.contains("豆奶") || lowercased.contains("soy milk") || lowercased.contains("椰奶") ||
           lowercased.contains("coconut milk") || lowercased.contains("杏仁奶") || lowercased.contains("almond milk") ||
           lowercased.contains("燕麦奶") || lowercased.contains("oat milk") || lowercased.contains("奶粉") ||
           lowercased.contains("milk powder") || lowercased.contains("奶油") || lowercased.contains("黄油") ||
           lowercased.contains("butter") || lowercased.contains("芝士") || lowercased.contains("马苏里拉") ||
           lowercased.contains("mozzarella") || lowercased.contains("车达") || lowercased.contains("cheddar") ||
           lowercased.contains("帕马森") || lowercased.contains("parmesan") {
            return .dairy
        }
        
        // 饮料
        if lowercased.contains("水") || lowercased.contains("饮料") || lowercased.contains("果汁") ||
           lowercased.contains("juice") || lowercased.contains("coffee") || lowercased.contains("咖啡") ||
           lowercased.contains("茶") || lowercased.contains("tea") || lowercased.contains("可乐") ||
           lowercased.contains("cola") || lowercased.contains("汽水") || lowercased.contains("soda") ||
           lowercased.contains("啤酒") || lowercased.contains("beer") || lowercased.contains("红酒") ||
           lowercased.contains("wine") || lowercased.contains("白酒") || lowercased.contains("烈酒") ||
           lowercased.contains("whiskey") || lowercased.contains("vodka") || lowercased.contains("rum") ||
           lowercased.contains("矿泉水") || lowercased.contains("mineral water") || lowercased.contains("纯净水") ||
           lowercased.contains("purified water") || lowercased.contains("苏打水") || lowercased.contains("sparkling water") ||
           lowercased.contains("功能饮料") || lowercased.contains("energy drink") || lowercased.contains("运动饮料") ||
           lowercased.contains("sports drink") || lowercased.contains("豆浆") || lowercased.contains("柠檬水") ||
           lowercased.contains("lemonade") || lowercased.contains("奶茶") || lowercased.contains("milk tea") {
            return .beverages
        }
        
        // 调料 - 包含花椒、胡椒粉等
        if lowercased.contains("盐") || lowercased.contains("糖") || lowercased.contains("醋") ||
           lowercased.contains("酱油") || lowercased.contains("salt") || lowercased.contains("sugar") ||
           lowercased.contains("vinegar") || lowercased.contains("soy sauce") || lowercased.contains("oil") ||
           lowercased.contains("油") || lowercased.contains("料酒") || lowercased.contains("胡椒") ||
           lowercased.contains("花椒") || lowercased.contains("五香粉") || lowercased.contains("生抽") ||
           lowercased.contains("老抽") || lowercased.contains("蚝油") || lowercased.contains("sesame") ||
           lowercased.contains("芝麻") || lowercased.contains("香油") || lowercased == "葱花" ||
           lowercased.contains("八角") || lowercased.contains("star anise") || lowercased.contains("桂皮") ||
           lowercased.contains("cinnamon") || lowercased.contains("香叶") || lowercased.contains("bay leaf") ||
           lowercased.contains("丁香") || lowercased.contains("clove") || lowercased.contains("孜然") ||
           lowercased.contains("cumin") || lowercased.contains("茴香") || lowercased.contains("fennel") ||
           lowercased.contains("辣椒粉") || lowercased.contains("chili powder") || lowercased.contains("辣椒油") ||
           lowercased.contains("chili oil") || lowercased.contains("豆瓣酱") || lowercased.contains("doubanjiang") ||
           lowercased.contains("郫县豆瓣") || lowercased.contains("甜面酱") || lowercased.contains("海鲜酱") ||
           lowercased.contains("番茄酱") || lowercased.contains("ketchup") || lowercased.contains("沙拉酱") ||
           lowercased.contains("mayonnaise") || lowercased.contains("芥末") || lowercased.contains("mustard") ||
           lowercased.contains("咖喱") || lowercased.contains("curry") || lowercased.contains("味精") ||
           lowercased.contains("msg") || lowercased.contains("鸡精") || lowercased.contains("酵母") ||
           lowercased.contains("yeast") || lowercased.contains("淀粉") || lowercased.contains("starch") ||
           lowercased.contains("生粉") || lowercased.contains("corn starch") {
            return .condiments
        }
        
        // 谷物
        if lowercased.contains("面") || lowercased.contains("米") || lowercased.contains("面条") ||
           lowercased.contains("大米") || lowercased.contains("燕麦") || lowercased.contains("麦片") ||
           lowercased.contains("rice") || lowercased.contains("noodle") || lowercased.contains("bread") ||
           lowercased.contains("面包") || lowercased.contains("pasta") || lowercased.contains("意面") ||
           lowercased.contains("oats") || lowercased.contains("oatmeal") || lowercased.contains("小麦") ||
           lowercased.contains("wheat") || lowercased.contains("玉米粉") || lowercased.contains("corn flour") ||
           lowercased.contains("面粉") || lowercased.contains("flour") || lowercased.contains("糯米") ||
           lowercased.contains("glutinous rice") || lowercased.contains("黑米") || lowercased.contains("black rice") ||
           lowercased.contains("红米") || lowercased.contains("red rice") || lowercased.contains("小米") ||
           lowercased.contains("millet") || lowercased.contains("薏米") || lowercased.contains("barley") ||
           lowercased.contains("大麦") || lowercased.contains("荞麦") || lowercased.contains("buckwheat") ||
           lowercased.contains("藜麦") || lowercased.contains("quinoa") || lowercased.contains("土司") ||
           lowercased.contains("toast") || lowercased.contains("馒头") || lowercased.contains("包子") ||
           lowercased.contains("饺子皮") || lowercased.contains("dumpling wrapper") || lowercased.contains("馄饨皮") ||
           lowercased.contains("wonton wrapper") || lowercased.contains("春卷皮") || lowercased.contains("spring roll wrapper") ||
           lowercased.contains("通心粉") || lowercased.contains("macaroni") || lowercased.contains("拉面") ||
           lowercased.contains("ramen") || lowercased.contains("乌冬面") || lowercased.contains("udon") {
            return .grains
        }
        
        // 坚果类 (暂时归类为其他)
        if lowercased.contains("坚果") || lowercased.contains("nuts") || lowercased.contains("核桃") ||
           lowercased.contains("walnut") || lowercased.contains("杏仁") || lowercased.contains("almond") ||
           lowercased.contains("花生") || lowercased.contains("peanut") || lowercased.contains("腰果") ||
           lowercased.contains("cashew") || lowercased.contains("开心果") || lowercased.contains("pistachio") ||
           lowercased.contains("榛子") || lowercased.contains("hazelnut") || lowercased.contains("松子") ||
           lowercased.contains("pine nuts") || lowercased.contains("瓜子") || lowercased.contains("sunflower seeds") ||
           lowercased.contains("南瓜子") || lowercased.contains("pumpkin seeds") || lowercased.contains("芝麻") ||
           lowercased.contains("sesame seeds") || lowercased.contains("亚麻籽") || lowercased.contains("flax seeds") ||
           lowercased.contains("奇亚籽") || lowercased.contains("chia seeds") {
            return .other
        }
        
        // 豆类 (暂时归类为蔬菜)
        if lowercased.contains("豆") || lowercased.contains("beans") || lowercased.contains("黄豆") ||
           lowercased.contains("soybeans") || lowercased.contains("绿豆") || lowercased.contains("mung beans") ||
           lowercased.contains("红豆") || lowercased.contains("red beans") || lowercased.contains("黑豆") ||
           lowercased.contains("black beans") || lowercased.contains("蚕豆") || lowercased.contains("fava beans") ||
           lowercased.contains("豌豆") || lowercased.contains("peas") || lowercased.contains("扁豆") ||
           lowercased.contains("lentils") || lowercased.contains("鹰嘴豆") || lowercased.contains("chickpeas") ||
           lowercased.contains("芸豆") || lowercased.contains("kidney beans") {
            return .vegetables
        }
        
        // 默认为其他
        return .other
    }
    
    /// 获取类别的默认单位
    static func getDefaultUnitForCategory(_ category: FoodCategory) -> String {
        switch category {
        case .meat, .seafood, .vegetables, .fruits:
            return "g"
        case .dairy, .beverages:
            return "mL"
        case .eggs:
            return FoodItem.defaultUnit
        case .grains, .canned, .snacks, .frozen:
            return "g"
        case .condiments:
            return "mL"
        case .other:
            return FoodItem.defaultUnit
        }
    }
}