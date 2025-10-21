import Foundation
import SwiftData

@Model
final class NutritionInfo {
    var id: UUID
    var calories: Double?
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var servingSize: String?
    var servingUnit: String?
    
    init(calories: Double? = nil, protein: Double? = nil, carbohydrates: Double? = nil, fat: Double? = nil, fiber: Double? = nil, sugar: Double? = nil, sodium: Double? = nil, servingSize: String? = nil, servingUnit: String? = nil) {
        self.id = UUID()
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.servingSize = servingSize
        self.servingUnit = servingUnit
    }
}

struct NutritionTarget {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    
    static let adult = NutritionTarget(
        calories: 2000,
        protein: 50,
        carbohydrates: 300,
        fat: 65,
        fiber: 25,
        sodium: 2300
    )
}