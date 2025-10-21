import Foundation
import RegexBuilder

// A delegate class for parsing XML from the receipt AI
fileprivate class ReceiptXMLParserDelegate: NSObject, XMLParserDelegate {
    var parsedItems: [ParsedReceiptItem] = []
    
    private var currentItem: ParsedReceiptItem?
    private var currentElement: String = ""
    private var currentName: String = ""
    private var currentQuantity: String = ""
    private var currentCategory: String = ""
    
    // Called when the parser finds a new element
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            // Start a new item
            currentName = ""
            currentQuantity = ""
            currentCategory = ""
        }
    }
    
    // Called when the parser finds characters inside an element
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedString.isEmpty {
            switch currentElement {
            case "name":
                currentName += trimmedString
            case "quantity":
                currentQuantity += trimmedString
            case "category":
                currentCategory += trimmedString
            default:
                break
            }
        }
    }
    
    // Called when the parser finds the end of an element
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            // Finalize and add the current item
            let quantityValue = currentQuantity.isEmpty ? nil : currentQuantity
            let categoryValue = currentCategory.isEmpty ? nil : currentCategory
            
            if !currentName.isEmpty {
                let newItem = ParsedReceiptItem(name: currentName, quantity: quantityValue, category: categoryValue)
                parsedItems.append(newItem)
            }
        }
        currentElement = ""
    }
}


class ReceiptParser {
    static let shared = ReceiptParser()
    private let aiService = AIService.shared
    
    private init() {}
    
    private let foodKeywords = [
        "蔬菜", "菜", "水果", "果", "肉", "海鲜", "奶", "面包", "米", "面", "油", "调料", "酱",
        "蛋", "鸡蛋", "牛奶", "酸奶", "奶酪", "苹果", "香蕉", "橙子", "柠檬", "草莓", "葡萄",
        "土豆", "番茄", "黄瓜", "白菜", "萝卜", "洋葱", "蒜", "姜", "椒", "盐", "糖", "醋",
        "猪肉", "牛肉", "鸡肉", "鱼", "虾", "蟹", "豆腐", "豆", "坚果", "花生", "核桃",
        "韭菜", "菠菜", "芹菜", "茄子", "青椒", "胡萝卜", "冬瓜", "南瓜", "丝瓜", "豇豆",
        "青菜", "小白菜", "大白菜", "卷心菜", "包菜", "生菜", "菜花", "西兰花", "莴苣",
        "vegetable", "fruit", "meat", "seafood", "dairy", "bread", "rice", "noodle",
        "egg", "milk", "cheese", "apple", "banana", "orange", "tomato", "potato",
        "chicken", "beef", "pork", "fish", "shrimp", "tofu", "nuts", "cabbage", "carrot"
    ]
    
    private let commonFoodPhrases = [
        "soup dumplings chicken": "鸡肉小笼包",
        "chicken soup dumplings": "鸡肉小笼包",
        "soup dumplings": "小笼包",
        "pork dumplings": "猪肉饺子",
        "chicken dumplings": "鸡肉饺子",
        "beef dumplings": "牛肉饺子",
        "beef noodles": "牛肉面",
        "chicken noodles": "鸡肉面",
        "fried rice": "炒饭",
        "chicken fried rice": "鸡肉炒饭",
        "beef fried rice": "牛肉炒饭",
        "spring onion": "葱",
        "green onion": "葱",
        "bell pepper": "青椒",
        "sweet potato": "红薯",
        "chinese cabbage": "白菜",
        "napa cabbage": "大白菜",
        "bok choy": "小白菜",
        "snow peas": "荷兰豆",
        "baby corn": "玉米笋",
        "shiitake mushroom": "香菇",
        "oyster mushroom": "平菇",
        "chicken breast": "鸡胸肉",
        "chicken thigh": "鸡腿肉",
        "ground beef": "牛肉馅",
        "ground pork": "猪肉馅",
        "pork belly": "五花肉",
        "salmon fillet": "三文鱼片",
        "shrimp tempura": "天妇罗虾",
        "mixed vegetables": "混合蔬菜"
    ]
    
    func parseReceipt(from text: String) async throws -> ParsedReceipt {
        print("📄 开始解析收据文本，共 \(text.count) 个字符")
        
        let (items, parseMethod) = try await parseReceiptWithAI(from: text)
        
        let methodDescription = parseMethod == .ai ? "AI解析" : "传统解析"
        print("🔍 \(methodDescription)完成，找到 \(items.count) 个有效食品项目")
        for item in items {
            print("  - \(item.name) (数量: \(item.quantity ?? "未知"))")
        }
        
        return ParsedReceipt(
            purchaseDate: Date(),
            items: items,
            parseMethod: parseMethod
        )
    }
    
    private func parseReceiptWithAI(from text: String) async throws -> ([ParsedReceiptItem], ParseMethod) {
        // 移除重复的免费次数检查，让 AIService 统一处理
        
        let language = LocalizationManager.shared.selectedLanguage
        
        let systemPrompt: String
        let userPrompt: String
        
        if language == "zh-Hans" {
            systemPrompt = "你是一个专业的收据解析AI，专注于从OCR文本中提取烹饪用的基础食材。你的输出必须是一个完整、有效的XML，绝不能包含任何解释或非XML字符。响应必须以<receipt>开头，以</receipt>结尾。"
            userPrompt = """
            <INSTRUCTIONS>
            1.  **分析下方的 <RECEIPT_TEXT>。**
            2.  **仅识别** 可用于家庭烹饪的 **基础食材原料**。
            3.  **严格排除** 所有成品、半成品、零食、饮料和非食品项目。
                *   **包含**: 新鲜食材 (肉、蔬菜、水果)，厨房常备品 (米、面、油、调料)，以及基础乳制品 (牛奶、奶酪、蛋)。
                *   **排除**: 即食食品 (如寿司、便当)、方便食品 (如炒面、河粉、速冻餐)、零食 (薯片)、饮料 (汽水) 和加工食品 (罐头)。
            4.  **将输出格式化为单个XML文档**，并遵循 <XML_SCHEMA> 的规范。
            5.  **遵守以下规则:**
                *   根元素必须是 `<receipt>`。
                *   每个食材都在一个 `<item>` 标签内。
                *   `name`: 使用标准化的、简洁的中文名称 (例如："鸡胸肉"，而不是 "有机散养鸡胸肉 1磅装")。
                *   `quantity`: 如果能识别则提取，否则使用空标签 `<quantity></quantity>`。
                *   `category`: 必须是 schema 中提供的确切值之一。
                *   **仅输出** XML。绝对不要包含任何解释、致歉、代码块标记或额外的文本。
                *   如果未找到任何食材，输出 `<receipt></receipt>`。
            </INSTRUCTIONS>

            <XML_SCHEMA>
            <receipt>
              <item>
                <name>string</name>
                <quantity>string</quantity>
                <category>肉类|海鲜|蔬菜|水果|蛋类|乳制品|谷物|调料|其他</category>
              </item>
              ...
            </receipt>
            </XML_SCHEMA>

            <EXAMPLE>
            <receipt>
              <item>
                <name>鸡胸肉</name>
                <quantity>500g</quantity>
                <category>肉类</category>
              </item>
              <item>
                <name>苹果</name>
                <quantity></quantity>
                <category>水果</category>
              </item>
            </receipt>
            </EXAMPLE>

            <RECEIPT_TEXT>
            \(text)
            </RECEIPT_TEXT>
            """
        } else {
            systemPrompt = "You are an expert receipt-parsing AI focused on extracting raw cooking ingredients from OCR text. Your output must be a complete, valid XML document starting with <receipt> and ending with </receipt>. Never include explanations or non-XML characters."
            userPrompt = """
            <INSTRUCTIONS>
            1.  **Analyze the <RECEIPT_TEXT> below.**
            2.  **Identify ONLY raw cooking ingredients** suitable for home cooking.
            3.  **Strictly EXCLUDE** all prepared foods, semi-prepared meals, snacks, drinks, and non-food items.
                *   **INCLUDE**: Fresh items (meat, vegetables, fruit), pantry staples (rice, flour, oil, spices), and basic dairy (milk, cheese, eggs).
                *   **EXCLUDE**: Ready-to-eat meals (e.g., sushi), convenience foods (e.g., instant noodles, pad thai, frozen dinners), snacks (chips), drinks (soda), and processed foods (canned goods).
            4.  **Format the output as a single XML document** conforming to the <XML_SCHEMA>.
            5.  **Adhere to these rules:**
                *   The root element must be `<receipt>`.
                *   Each ingredient is within an `<item>` tag.
                *   `name`: Use a standardized, simple English name (e.g., "Chicken Breast", not "Organic Chicken Breast 1lb").
                *   `quantity`: Extract if possible, otherwise use an empty tag: `<quantity></quantity>`.
                *   `category`: Must be one of the schema values: "Meat", "Seafood", "Vegetables", "Fruits", "Eggs", "Dairy", "Grains", "Seasonings", "Other".
                *   Output ONLY the XML. Never include explanations, apologies, or code blocks.
                *   If no ingredients are found, output `<receipt></receipt>`.
            </INSTRUCTIONS>

            <XML_SCHEMA>
            <receipt>
              <item>
                <name>string</name>
                <quantity>string</quantity>
                <category>Meat|Seafood|Vegetables|Fruits|Eggs|Dairy|Grains|Seasonings|Other</category>
              </item>
              ...
            </receipt>
            </XML_SCHEMA>

            <EXAMPLE>
            <receipt>
              <item>
                <name>Chicken Breast</name>
                <quantity>500g</quantity>
                <category>Meat</category>
              </item>
              <item>
                <name>Apples</name>
                <quantity></quantity>
                <category>Fruits</category>
              </item>
            </receipt>
            </EXAMPLE>

            <RECEIPT_TEXT>
            \(text)
            </RECEIPT_TEXT>
            """
        }
        
        do {
            let response = try await aiService.simpleTextGeneration(message: userPrompt, systemPrompt: systemPrompt)
            // AI调用成功，AIService已经消耗了使用次数，这里不需要重复扣费
            
            let result = try parseXMLResponse(response)
            return (result, .ai)
        } catch {
            print("❌ AI解析失败，回退到传统方法: \(error)")
            // AIService已经处理了扣费逻辑，这里不需要额外处理
            
            // 回退到传统解析方法（不消耗额外次数）
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let traditionalResult = await extractItemsWithAI(from: lines)
            return (traditionalResult, .traditional)
        }
    }
    
    private func parseXMLResponse(_ response: String) throws -> [ParsedReceiptItem] {
        print("📝 AI XML响应长度: \(response.count)")
        
        // Simple cleanup, remove potential code block markers
        let cleanedResponse = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```xml", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            print("❌ 无法将响应转换为UTF-8数据")
            throw ReceiptScanError.parsingFailed
        }
        
        let parser = XMLParser(data: data)
        let delegate = ReceiptXMLParserDelegate()
        parser.delegate = delegate
        
        if parser.parse() {
            print("✅ XML解析成功，找到 \(delegate.parsedItems.count) 个项目")
            return delegate.parsedItems
        } else {
            print("❌ XML解析失败: \(parser.parserError?.localizedDescription ?? "未知错误")")
            print("❌ 响应内容前500字符: \(String(cleanedResponse.prefix(500)))")
            throw ReceiptScanError.parsingFailed
        }
    }
    
    private func extractItemsWithAI(from lines: [String]) async -> [ParsedReceiptItem] {
        print("🔍 使用传统方法解析商品")
        
        let items = extractItems(from: lines)
        
        print("✅ 传统解析完成，找到 \(items.count) 个食品项目")
        return items
    }
    
    private func extractItems(from lines: [String]) -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []
        
        for line in lines {
            if let item = parseItemLine(line) {
                items.append(item)
            }
        }
        
        return items.filter { item in
            isFoodItem(item.name)
        }
    }
    
    private func isFoodItem(_ itemName: String) -> Bool {
        let lowercaseName = itemName.lowercased()
        
        let basicFoodCheck = foodKeywords.contains { keyword in
            lowercaseName.contains(keyword.lowercased())
        }
        
        let phraseCheck = commonFoodPhrases.keys.contains { phrase in
            lowercaseName.contains(phrase.lowercased())
        }
        
        let patternCheck = matchesFoodPatterns(lowercaseName)
        
        return (basicFoodCheck || phraseCheck || patternCheck) && 
               itemName.count >= 2 && 
               !isExcludedItem(itemName)
    }
    
    private func matchesFoodPatterns(_ itemName: String) -> Bool {
        let foodPatterns = [
            ".*dumpling.*",
            ".*soup.*",
            ".*meat.*",
            ".*chicken.*",
            ".*beef.*",
            ".*pork.*",
            ".*fish.*",
            ".*vegetable.*",
            ".*noodle.*",
            ".*rice.*",
            ".*bread.*",
            ".*cheese.*",
            ".*fruit.*",
            ".*berry.*",
            ".*apple.*",
            ".*milk.*",
            ".*yogurt.*",
            ".*juice.*"
        ]
        
        for pattern in foodPatterns {
            if itemName.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func isExcludedItem(_ itemName: String) -> Bool {
        let excludedItems = [
            "小计", "合计", "总计", "找零", "应收", "实收", "优惠", "折扣", "税",
            "袋子", "购物袋", "塑料袋", "发票", "收据", 
            "subtotal", "total", "tax", "discount", "change", "receipt", "bag"
        ]
        
        return excludedItems.contains { excluded in
            itemName.localizedCaseInsensitiveContains(excluded)
        }
    }
    
    private func parseItemLine(_ line: String) -> ParsedReceiptItem? {
        guard !isNonItemLine(line) else { return nil }
        
        // 使用具体的正则表达式类型
        let quantityPattern = try! Regex("([x×*]\\s*\\d+|\\d+\\s*[个只袋斤公斤kg包盒瓶罐])")
        let pricePattern = try! Regex("([¥￥$]?\\d+\\.?\\d*)")
        
        var itemName = line
        var quantity: String?
        
        // 先移除价格信息，避免干扰识别
        let priceMatches = line.matches(of: pricePattern)
        if let lastPriceMatch = priceMatches.last {
            let matchedText = String(line[lastPriceMatch.range])
            itemName = itemName.replacingOccurrences(of: matchedText, with: "")
        }
        
        if let quantityMatch = itemName.firstMatch(of: quantityPattern) {
            let matchedText = String(itemName[quantityMatch.range])
            quantity = matchedText
            itemName = itemName.replacingOccurrences(of: matchedText, with: "")
        }
        
        itemName = itemName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        guard !itemName.isEmpty && itemName.count >= 2 else { return nil }
        
        return ParsedReceiptItem(
            name: itemName,
            quantity: quantity,
            category: categorizeItem(itemName)
        )
    }
    
    private func isNonItemLine(_ line: String) -> Bool {
        let excludePatterns = [
            "小计", "合计", "总计", "找零", "应收", "实收", "优惠", "折扣", "税",
            "subtotal", "total", "tax", "discount", "change", "receipt",
            "谢谢", "欢迎", "thank", "welcome", "店", "地址", "电话", "tel",
            "收银", "cashier", "时间", "time", "日期", "date"
        ]
        
        return excludePatterns.contains { pattern in
            line.localizedCaseInsensitiveContains(pattern)
        } || line.count < 2 || line.allSatisfy { $0.isNumber || $0.isPunctuation || $0.isWhitespace }
    }
    
    private func categorizeItem(_ itemName: String) -> String? {
        let categories = [
            "produce": ["蔬菜", "菜", "白菜", "萝卜", "土豆", "番茄", "黄瓜", "洋葱", "蒜", "生姜", "韭菜", "菠菜", "芹菜", "水果", "果", "苹果", "香蕉", "橙子", "柠檬", "草莓", "葡萄", "西瓜", "vegetable", "tomato", "potato", "onion", "garlic", "fruit", "apple", "banana", "orange", "lemon", "strawberry", "grape"],
            "meat": ["肉", "猪肉", "牛肉", "鸡肉", "羊肉", "meat", "pork", "beef", "chicken", "lamb"],
            "seafood": ["鱼", "虾", "蟹", "贝", "海鲜", "fish", "shrimp", "crab", "seafood"],
            "eggs": ["蛋", "鸡蛋", "鸭蛋", "鹌鹑蛋", "egg", "eggs"],
            "dairy": ["奶", "牛奶", "酸奶", "奶酪", "黄油", "milk", "yogurt", "cheese", "butter"],
            "grains": ["米", "面", "面包", "面条", "饺子", "rice", "bread", "noodle", "pasta"],
            "condiments": ["盐", "糖", "醋", "酱油", "油", "胡椒", "调料", "sauce", "salt", "sugar", "oil", "pepper"],
            "snacks": ["饼干", "薯片", "糖果", "巧克力", "坚果", "cookie", "chips", "candy", "chocolate", "nuts"]
        ]
        
        for (category, keywords) in categories {
            if keywords.contains(where: { itemName.localizedCaseInsensitiveContains($0) }) {
                return category
            }
        }
        
        return nil
    }
    
    
    private func preProcessItemName(_ itemName: String) -> String {
        var processedName = itemName.lowercased()
        
        processedName = processedName.replacingOccurrences(of: "\\b(fresh|frozen|organic|free-range)\\b", with: "", options: .regularExpression)
        processedName = processedName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        processedName = processedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return processedName
    }
    
    private func getQuickTranslation(_ itemName: String) -> String? {
        let lowercaseName = itemName.lowercased()
        let language = LocalizationManager.shared.selectedLanguage
        
        if language == "zh-Hans" {
            // 中文模式：英文 -> 中文
            let sortedPhrases = commonFoodPhrases.keys.sorted { $0.count > $1.count }
            for englishPhrase in sortedPhrases {
                if lowercaseName.contains(englishPhrase.lowercased()) {
                    return commonFoodPhrases[englishPhrase]
                }
            }
            
            if let smartTranslation = getSmartWordTranslation(lowercaseName) {
                return smartTranslation
            }
        } else {
            // 英文模式：标准化英文名称
            return getStandardizedEnglishName(lowercaseName)
        }
        
        return nil
    }
    
    private func getStandardizedEnglishName(_ itemName: String) -> String? {
        let englishStandardizations = [
            "soup dumplings chicken": "Chicken Soup Dumplings",
            "chicken soup dumplings": "Chicken Soup Dumplings", 
            "soup dumplings": "Soup Dumplings",
            "pork dumplings": "Pork Dumplings",
            "chicken dumplings": "Chicken Dumplings",
            "beef dumplings": "Beef Dumplings",
            "beef noodles": "Beef Noodles",
            "chicken noodles": "Chicken Noodles",
            "fried rice": "Fried Rice",
            "chicken fried rice": "Chicken Fried Rice",
            "beef fried rice": "Beef Fried Rice",
            "spring onion": "Green Onion",
            "green onion": "Green Onion",
            "bell pepper": "Bell Pepper",
            "sweet potato": "Sweet Potato",
            "chinese cabbage": "Chinese Cabbage",
            "napa cabbage": "Napa Cabbage",
            "bok choy": "Bok Choy",
            "snow peas": "Snow Peas",
            "baby corn": "Baby Corn",
            "shiitake mushroom": "Shiitake Mushroom",
            "oyster mushroom": "Oyster Mushroom",
            "chicken breast": "Chicken Breast",
            "chicken thigh": "Chicken Thigh",
            "ground beef": "Ground Beef",
            "ground pork": "Ground Pork",
            "pork belly": "Pork Belly",
            "salmon fillet": "Salmon Fillet"
        ]
        
        let sortedPhrases = englishStandardizations.keys.sorted { $0.count > $1.count }
        for phrase in sortedPhrases {
            if itemName.contains(phrase) {
                return englishStandardizations[phrase]
            }
        }
        
        return nil
    }
    
    private func getSmartWordTranslation(_ itemName: String) -> String? {
        let wordMappings = [
            "chicken": "鸡肉",
            "beef": "牛肉", 
            "pork": "猪肉",
            "fish": "鱼",
            "salmon": "三文鱼",
            "tuna": "金枪鱼",
            "shrimp": "虾",
            "crab": "蟹",
            "dumpling": "饺子",
            "dumplings": "饺子",
            "noodle": "面条",
            "noodles": "面条",
            "rice": "米饭",
            "vegetable": "蔬菜",
            "vegetables": "蔬菜",
            "fruit": "水果",
            "fruits": "水果",
            "milk": "牛奶",
            "egg": "鸡蛋",
            "eggs": "鸡蛋",
            "bread": "面包",
            "tofu": "豆腐",
            "mushroom": "蘑菇",
            "mushrooms": "蘑菇",
            "cabbage": "白菜",
            "carrot": "胡萝卜",
            "carrots": "胡萝卜",
            "potato": "土豆",
            "potatoes": "土豆",
            "tomato": "番茄",
            "tomatoes": "番茄",
            "onion": "洋葱",
            "onions": "洋葱",
            "soup": "汤",
            "fried": "炒",
            "steamed": "蒸",
            "boiled": "煮",
            "grilled": "烤"
        ]
        
        let words = itemName.components(separatedBy: .whitespaces)
        var mainIngredients: [String] = []
        var cookingMethods: [String] = []
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if let translation = wordMappings[cleanWord] {
                if ["炒", "蒸", "煮", "烤", "汤"].contains(translation) {
                    cookingMethods.append(translation)
                } else {
                    mainIngredients.append(translation)
                }
            }
        }
        
        if !mainIngredients.isEmpty {
            let result = cookingMethods.joined() + mainIngredients.joined()
            return result.isEmpty ? nil : result
        }
        
        return nil
    }
    
    
}