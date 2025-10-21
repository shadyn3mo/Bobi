import Foundation

// MARK: - Enhanced Recipe Response Models
struct RecipeResponse {
    let dishes: [Dish]
    let isError: Bool
    let errorCode: String?
    let errorMessage: String?
    
    static func error(code: String, message: String) -> RecipeResponse {
        return RecipeResponse(dishes: [], isError: true, errorCode: code, errorMessage: message)
    }
    
    static func success(dishes: [Dish]) -> RecipeResponse {
        return RecipeResponse(dishes: dishes, isError: false, errorCode: nil, errorMessage: nil)
    }
}

struct Dish {
    let name: String
    let cuisine: String
    let nutritionHighlight: String
    let ingredients: [IngredientGroup]
    let steps: [CookingStep]
    let healthyTip: String
    let pairingSuggestion: String
}

struct IngredientGroup {
    let type: IngredientGroupType
    let items: [RecipeIngredient]
}

enum IngredientGroupType: String, CaseIterable {
    case main = "Main"
    case side = "Side" 
    case seasoning = "Seasoning"
    
    var localizedName: String {
        switch self {
        case .main: return "recipe.ingredient.main".localized
        case .side: return "recipe.ingredient.side".localized
        case .seasoning: return "recipe.ingredient.seasoning".localized
        }
    }
}

struct RecipeIngredient {
    let name: String
    let quantity: String
    let unit: String
    let status: IngredientStatus
}

enum IngredientStatus: String, CaseIterable {
    case available = "available"
    case new = "new"
    
    var localizedName: String {
        switch self {
        case .available: return "recipe.ingredient.available".localized
        case .new: return "recipe.ingredient.new".localized
        }
    }
}

struct CookingStep {
    let index: Int
    let description: String
}

// MARK: - Enterprise-Grade XML Parser
class RecipeParser: NSObject {
    static let shared = RecipeParser()
    
    private override init() {
        super.init()
    }
    
    func parseRecipeResponse(_ xmlString: String) -> RecipeResponse {
        // First, try XML parsing
        if let xmlResponse = parseXMLResponse(xmlString) {
            return xmlResponse
        }
        
        // Fallback to legacy text parsing for backward compatibility
        return parseLegacyResponse(xmlString)
    }
    
    // MARK: - XML Parsing (Primary Method)
    private func parseXMLResponse(_ xmlString: String) -> RecipeResponse? {
        guard xmlString.contains("<RecipeResponse>") || xmlString.contains("<Error>") else {
            return nil
        }
        
        // Clean up the XML string to remove markdown code blocks and extra formatting
        let cleanedXML = cleanXMLString(xmlString)
        
        let data = Data(cleanedXML.utf8)
        let parser = XMLParser(data: data)
        let delegate = RecipeXMLParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            print("⚠️ XML Parsing failed, falling back to legacy parser")
            print("🔍 Failed XML content: \(cleanedXML.prefix(500))")
            return nil
        }
        
        if let error = delegate.error {
            return RecipeResponse.error(code: error.code, message: error.message)
        }
        
        return RecipeResponse.success(dishes: delegate.dishes)
    }
    
    // MARK: - XML Cleaning Helper
    private func cleanXMLString(_ input: String) -> String {
        var cleaned = input
        
        // Remove markdown code blocks
        cleaned = cleaned.replacingOccurrences(of: "```xml", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        
        // Remove any leading/trailing whitespace and newlines
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the start and end of the XML content
        if let startRange = cleaned.range(of: "<RecipeResponse>"),
           let endRange = cleaned.range(of: "</RecipeResponse>") {
            let start = startRange.lowerBound
            let end = endRange.upperBound
            cleaned = String(cleaned[start..<end])
        } else if let startRange = cleaned.range(of: "<Error>"),
                  let endRange = cleaned.range(of: "</Error>") {
            let start = startRange.lowerBound
            let end = endRange.upperBound
            cleaned = String(cleaned[start..<end])
        }
        
        return cleaned
    }
    
    // MARK: - Legacy Text Parsing (Fallback)
    private func parseLegacyResponse(_ response: String) -> RecipeResponse {
        var dishes: [Dish] = []
        let lines = response.components(separatedBy: .newlines)
        
        var currentDish: [String: Any] = [:]
        var ingredients: [RecipeIngredient] = []
        var steps: [CookingStep] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.hasPrefix("[菜名]") || trimmed.hasPrefix("[Dish Name]") {
                if !currentDish.isEmpty {
                    // Save previous dish
                    if let dish = createDishFromLegacyData(currentDish, ingredients: ingredients, steps: steps) {
                        dishes.append(dish)
                    }
                }
                
                // Start new dish
                currentDish = [:]
                ingredients = []
                steps = []
                
                let name = trimmed.replacingOccurrences(of: "[菜名]", with: "")
                    .replacingOccurrences(of: "[Dish Name]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentDish["name"] = name
                
            } else if trimmed.hasPrefix("[菜系]") || trimmed.hasPrefix("[Cuisine]") {
                let cuisine = extractValue(from: trimmed, removing: ["[菜系]", "[Cuisine]"])
                currentDish["cuisine"] = cuisine
                
            } else if trimmed.hasPrefix("[营养亮点]") || trimmed.hasPrefix("[Nutrition]") {
                let nutrition = extractValue(from: trimmed, removing: ["[营养亮点]", "[Nutrition]"])
                currentDish["nutrition"] = nutrition
                
            } else if trimmed.hasPrefix("- 主料:") || trimmed.hasPrefix("- Main:") {
                let ingredientText = extractValue(from: trimmed, removing: ["- 主料:", "- Main:"])
                ingredients.append(contentsOf: parseIngredientLine(ingredientText, type: .main))
                
            } else if trimmed.hasPrefix("- 配料:") || trimmed.hasPrefix("- Side:") {
                let ingredientText = extractValue(from: trimmed, removing: ["- 配料:", "- Side:"])
                ingredients.append(contentsOf: parseIngredientLine(ingredientText, type: .side))
                
            } else if trimmed.hasPrefix("- 调料:") || trimmed.hasPrefix("- Seasoning:") {
                let ingredientText = extractValue(from: trimmed, removing: ["- 调料:", "- Seasoning:"])
                ingredients.append(contentsOf: parseIngredientLine(ingredientText, type: .seasoning))
            }
        }
        
        // Add last dish
        if !currentDish.isEmpty {
            if let dish = createDishFromLegacyData(currentDish, ingredients: ingredients, steps: steps) {
                dishes.append(dish)
            }
        }
        
        return RecipeResponse.success(dishes: dishes)
    }
    
    private func extractValue(from line: String, removing prefixes: [String]) -> String {
        var result = line
        for prefix in prefixes {
            result = result.replacingOccurrences(of: prefix, with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func parseIngredientLine(_ line: String, type: IngredientGroupType) -> [RecipeIngredient] {
        let components = line.components(separatedBy: ",")
        return components.compactMap { component in
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            
            // Parse format: "Name Quantity Unit" or "Name: Quantity Unit"
            let parts = trimmed.replacingOccurrences(of: ":", with: "").components(separatedBy: " ")
            guard parts.count >= 2 else {
                return RecipeIngredient(name: trimmed, quantity: "", unit: "", status: .available)
            }
            
            let name = parts[0]
            let quantityUnit = parts[1]
            
            // Extract quantity and unit
            let quantity = quantityUnit.filter { $0.isNumber }
            let unit = quantityUnit.filter { !$0.isNumber }
            
            return RecipeIngredient(
                name: name,
                quantity: quantity,
                unit: unit,
                status: .available
            )
        }
    }
    
    private func createDishFromLegacyData(_ data: [String: Any], ingredients: [RecipeIngredient], steps: [CookingStep]) -> Dish? {
        guard let name = data["name"] as? String else { return nil }
        
        let ingredientGroups = Dictionary(grouping: ingredients) { $0.status }
        let mainGroup = IngredientGroup(type: .main, items: ingredientGroups[.available] ?? [])
        
        return Dish(
            name: name,
            cuisine: data["cuisine"] as? String ?? "",
            nutritionHighlight: data["nutrition"] as? String ?? "",
            ingredients: [mainGroup],
            steps: steps,
            healthyTip: "",
            pairingSuggestion: ""
        )
    }
}

// MARK: - XML Parser Delegate
class RecipeXMLParserDelegate: NSObject, XMLParserDelegate {
    var dishes: [Dish] = []
    var error: (code: String, message: String)?
    
    private var currentElement = ""
    private var currentDish: [String: Any] = [:]
    private var currentIngredientGroup: [String: Any] = [:]
    private var currentIngredients: [RecipeIngredient] = []
    private var currentSteps: [CookingStep] = []
    private var elementContent = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        elementContent = ""
        
        switch elementName {
        case "Error":
            // Error response detected
            break
        case "Dish":
            currentDish = [:]
            currentSteps = []
        case "Group":
            currentIngredientGroup = attributeDict
            currentIngredients = []
        case "Item":
            if let name = attributeDict["name"],
               let quantity = attributeDict["quantity"],
               let unit = attributeDict["unit"],
               let statusString = attributeDict["status"],
               let status = IngredientStatus(rawValue: statusString) {
                
                let ingredient = RecipeIngredient(
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    status: status
                )
                currentIngredients.append(ingredient)
            } else {
                print("⚠️ [XML] Failed to parse item attributes: \(attributeDict)")
            }
        case "Step":
            if let indexString = attributeDict["index"], let index = Int(indexString) {
                currentDish["stepIndex"] = index
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        elementContent += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let content = elementContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch elementName {
        case "Code":
            if error == nil {
                error = (code: content, message: "")
            } else {
                error = (code: content, message: error?.message ?? "")
            }
        case "Message":
            if let existingError = error {
                error = (code: existingError.code, message: content)
            } else {
                error = (code: "", message: content)
            }
        case "Name":
            currentDish["name"] = content
        case "Cuisine":
            currentDish["cuisine"] = content
        case "NutritionHighlight":
            currentDish["nutrition"] = content
        case "HealthyTip":
            currentDish["healthyTip"] = content
        case "PairingSuggestion":
            currentDish["pairingSuggestion"] = content
        case "Step":
            if let index = currentDish["stepIndex"] as? Int {
                let step = CookingStep(index: index, description: content)
                currentSteps.append(step)
            }
        case "Group":
            if let typeString = currentIngredientGroup["type"] as? String,
               let type = IngredientGroupType(rawValue: typeString) {
                let group = IngredientGroup(type: type, items: currentIngredients)
                
                var groups = currentDish["ingredientGroups"] as? [IngredientGroup] ?? []
                groups.append(group)
                currentDish["ingredientGroups"] = groups
            } else {
                print("⚠️ [XML] Failed to create group from: \(currentIngredientGroup)")
            }
        case "Dish":
            if let dish = createDishFromXMLData() {
                dishes.append(dish)
            } else {
                print("⚠️ [XML] Failed to create dish from data: \(currentDish)")
            }
        default:
            break
        }
        
        currentElement = ""
        elementContent = ""
    }
    
    private func createDishFromXMLData() -> Dish? {
        guard let name = currentDish["name"] as? String else { return nil }
        
        return Dish(
            name: name,
            cuisine: currentDish["cuisine"] as? String ?? "",
            nutritionHighlight: currentDish["nutrition"] as? String ?? "",
            ingredients: currentDish["ingredientGroups"] as? [IngredientGroup] ?? [],
            steps: currentSteps,
            healthyTip: currentDish["healthyTip"] as? String ?? "",
            pairingSuggestion: currentDish["pairingSuggestion"] as? String ?? ""
        )
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // XML parsing error occurred
    }
}