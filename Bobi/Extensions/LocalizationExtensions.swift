import Foundation

// MARK: - Enhanced Localization Support
// String localization extension is already defined in LocalizationHelper.swift

// MARK: - Enum Localization Extensions

extension ActivityLevel {
    var localizedName: String {
        switch self {
        case .sedentary: return "activity.level.sedentary".localized
        case .light: return "activity.level.light".localized
        case .moderate: return "activity.level.moderate".localized
        case .active: return "activity.level.active".localized
        case .veryActive: return "activity.level.very.active".localized
        }
    }
}

extension DietaryRestriction {
    var localizedName: String {
        switch self {
        case .vegetarian: return "family.dietary.vegetarian".localized
        case .vegan: return "family.dietary.vegan".localized
        case .glutenFree: return "family.dietary.glutenFree".localized
        case .dairyFree: return "family.dietary.dairyFree".localized
        case .nutFree: return "family.dietary.nutFree".localized
        case .lowSodium: return "family.dietary.lowSodium".localized
        case .diabetic: return "family.dietary.diabetic".localized
        case .kosher: return "family.dietary.kosher".localized
        case .halal: return "family.dietary.halal".localized
        case .shellFishAllergy: return "family.allergy.shellfish".localized
        case .eggAllergy: return "family.allergy.egg".localized
        case .fishAllergy: return "family.allergy.fish".localized
        case .soyAllergy: return "family.allergy.soy".localized
        case .wheatAllergy: return "family.allergy.wheat".localized
        case .sesameAllergy: return "family.allergy.sesame".localized
        case .sulfiteAllergy: return "family.allergy.sulfite".localized
        case .mushroomAllergy: return "family.allergy.mushroom".localized
        }
    }
}

extension Gender {
    var localizedName: String {
        switch self {
        case .male: return "family.management.male".localized
        case .female: return "family.management.female".localized
        }
    }
}

// MARK: - Age Category Extension

extension FamilyMember {
    var ageCategoryLocalizedName: String {
        switch self.ageCategory {
        case .baby: return "age.category.baby".localized
        case .child: return "age.category.child".localized
        case .youth: return "age.category.youth".localized
        case .adult: return "age.category.adult".localized
        case .senior: return "age.category.senior".localized
        }
    }
    
    var ageDescription: String {
        if age == 0 && monthsForBaby > 0 {
            return "\(monthsForBaby) " + "family.management.months.old".localized
        } else {
            return "\(self.age) " + "family.management.years.old".localized
        }
    }
}

// MARK: - Family Management Helpers

extension FamilyProfile {
    var displayName: String {
        if !self.name.isEmpty {
            let defaultNames = ["family.management.my.family".localized]
            if defaultNames.contains(self.name) {
                return self.name
            } else {
                return self.name + "family.possessive.suffix".localized
            }
        } else {
            return "family.management.unnamed.family".localized
        }
    }
    
    static var defaultFamilyName: String {
        return "family.management.my.family".localized
    }
}

// MARK: - Recipe Setup Localization Helpers

struct RecipeSetupLocalizations {
    static let title = "recipe.setup.title".localized
    static let description = "recipe.setup.description".localized
    static let setupNow = "recipe.setup.now".localized
    static let setupLater = "recipe.setup.later".localized
}

struct FamilyManagementLocalizations {
    static let title = "family.management.title".localized
    static let done = "family.management.done".localized
    static let save = "family.management.save".localized
    static let edit = "family.management.edit".localized
    static let cancel = "family.management.cancel".localized
    static let addMember = "family.management.add.member".localized
    static let editMember = "family.management.edit.member".localized
    static let familyName = "family.management.family.name".localized
    static let familyMembers = "family.management.family.members".localized
    static let noMembers = "family.management.no.members".localized
    static let enterFamilyName = "family.management.enter.family.name".localized
    static let tapAddMembers = "family.management.tap.add.members".localized
    static let basicInformation = "family.management.basic.information".localized
    static let dietaryRestrictions = "family.management.dietary.restrictions".localized
    static let name = "family.management.name".localized
    static let age = "family.management.age".localized
    static let gender = "family.management.gender".localized
    static let height = "family.management.height".localized
    static let weight = "family.management.weight".localized
    static let activityLevel = "family.management.activity.level".localized
    static let familyStatistics = "family.management.family.statistics".localized
    static let totalMembers = "family.management.total.members".localized
    static let babies = "family.management.babies".localized
    static let children = "family.management.children".localized
    static let youngAdults = "family.management.youth".localized
    static let middleAged = "family.management.adult".localized
    static let elderly = "family.management.senior".localized
}

// MARK: - App Settings Localization Helpers

struct AppSettingsLocalizations {
    static let changeAppIcon = "app.icon.change".localized
    static let feedbackBeta = "feedback.beta".localized
    static let gogofridgeAndMe = "gogofridge.and.me".localized
}