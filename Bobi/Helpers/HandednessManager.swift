import Foundation
import SwiftUI

enum Handedness: String, CaseIterable {
    case rightHanded = "right"
    case leftHanded = "left"
    
    var localizedName: String {
        switch self {
        case .rightHanded:
            return "interface.right.handed".localized
        case .leftHanded:
            return "interface.left.handed".localized
        }
    }
}

@Observable
class HandednessManager {
    var selectedHandedness: Handedness {
        didSet {
            UserDefaults.standard.set(selectedHandedness.rawValue, forKey: "selectedHandedness")
        }
    }
    
    static let shared = HandednessManager()
    
    private init() {
        let savedHandedness = UserDefaults.standard.string(forKey: "selectedHandedness") ?? Handedness.rightHanded.rawValue
        self.selectedHandedness = Handedness(rawValue: savedHandedness) ?? .rightHanded
    }
    
    var isRightHanded: Bool {
        return selectedHandedness == .rightHanded
    }
    
    var isLeftHanded: Bool {
        return selectedHandedness == .leftHanded
    }
}