import SwiftUI

/// 响应式设计工具类，根据屏幕尺寸提供适配值
struct ResponsiveDesign {
    private static let screenWidth = UIScreen.main.bounds.width
    private static let screenHeight = UIScreen.main.bounds.height
    
    /// 设备类型枚举
    enum DeviceSize {
        case compact    // iPhone SE, iPhone mini
        case regular    // iPhone 标准尺寸
        case large      // iPhone Plus/Pro Max
        
        static var current: DeviceSize {
            switch screenWidth {
            case ..<375:
                return .compact
            case 375..<414:
                return .regular  
            default:
                return .large
            }
        }
    }
    
    /// 动态间距
    struct Spacing {
        static var small: CGFloat {
            switch DeviceSize.current {
            case .compact: return 8
            case .regular: return 12
            case .large: return 16
            }
        }
        
        static var medium: CGFloat {
            switch DeviceSize.current {
            case .compact: return 12
            case .regular: return 16
            case .large: return 20
            }
        }
        
        static var large: CGFloat {
            switch DeviceSize.current {
            case .compact: return 16
            case .regular: return 20
            case .large: return 24
            }
        }
        
        static var extraLarge: CGFloat {
            switch DeviceSize.current {
            case .compact: return 20
            case .regular: return 24
            case .large: return 32
            }
        }
    }
    
    /// 动态按钮尺寸
    struct ButtonSize {
        static var small: CGFloat {
            switch DeviceSize.current {
            case .compact: return 32
            case .regular: return 40
            case .large: return 44
            }
        }
        
        static var medium: CGFloat {
            switch DeviceSize.current {
            case .compact: return 44
            case .regular: return 52
            case .large: return 56
            }
        }
        
        static var large: CGFloat {
            switch DeviceSize.current {
            case .compact: return 56
            case .regular: return 64
            case .large: return 72
            }
        }
        
        static var extraLarge: CGFloat {
            switch DeviceSize.current {
            case .compact: return 80
            case .regular: return 100
            case .large: return 120
            }
        }
    }
    
    /// 动态图标尺寸
    struct IconSize {
        static var small: CGFloat {
            switch DeviceSize.current {
            case .compact: return 16
            case .regular: return 20
            case .large: return 24
            }
        }
        
        static var medium: CGFloat {
            switch DeviceSize.current {
            case .compact: return 24
            case .regular: return 28
            case .large: return 32
            }
        }
        
        static var large: CGFloat {
            switch DeviceSize.current {
            case .compact: return 32
            case .regular: return 40
            case .large: return 48
            }
        }
    }
    
    /// 动态列数
    struct GridColumns {
        static var emoji: Int {
            switch DeviceSize.current {
            case .compact: return 4
            case .regular: return 5
            case .large: return 6
            }
        }
        
        static var foodGrid: Int {
            switch DeviceSize.current {
            case .compact: return 1
            case .regular: return 2
            case .large: return 2
            }
        }
    }
    
    /// 动态圆角半径
    struct CornerRadius {
        static var small: CGFloat {
            switch DeviceSize.current {
            case .compact: return 8
            case .regular: return 10
            case .large: return 12
            }
        }
        
        static var medium: CGFloat {
            switch DeviceSize.current {
            case .compact: return 12
            case .regular: return 16
            case .large: return 20
            }
        }
        
        static var large: CGFloat {
            switch DeviceSize.current {
            case .compact: return 16
            case .regular: return 20
            case .large: return 24
            }
        }
    }
    
    /// 安全区域适配底部内边距
    static var safeAreaBottomPadding: CGFloat {
        let safeAreaBottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        switch DeviceSize.current {
        case .compact: return max(safeAreaBottom, 16)
        case .regular: return max(safeAreaBottom, 20)
        case .large: return max(safeAreaBottom, 24)
        }
    }
    
    /// 浮动按钮底部间距
    static var floatingButtonBottomPadding: CGFloat {
        switch DeviceSize.current {
        case .compact: return safeAreaBottomPadding + 80
        case .regular: return safeAreaBottomPadding + 100
        case .large: return safeAreaBottomPadding + 120
        }
    }
}

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}