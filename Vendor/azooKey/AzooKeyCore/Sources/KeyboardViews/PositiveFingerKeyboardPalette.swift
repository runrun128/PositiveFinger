import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Matches the catalog colors when asset compilation is unavailable.
enum PositiveFingerKeyboardPalette {
    static func color(named name: String) -> Color {
#if canImport(UIKit)
        if let color = UIColor(named: name) { return Color(uiColor: color) }
        return Color(uiColor: UIColor { traits in
            switch name {
            case "BackGroundColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) }
                return UIColor(red: 0.8431372549019608, green: 0.8470588235294118, blue: 0.8666666666666667, alpha: 1.0)
            case "BackGroundColor_iOS15":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) }
                return UIColor(displayP3Red: 0.8196078431372549, green: 0.8235294117647058, blue: 0.8470588235294118, alpha: 1.0)
            case "FlickhighlightedKeyColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.224, green: 0.227, blue: 0.235, alpha: 1.0) }
                return UIColor(red: 0.869, green: 0.882, blue: 0.901, alpha: 1.0)
            case "HighlightedKeyColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.169, green: 0.173, blue: 0.18, alpha: 1.0) }
                return UIColor(red: 0.929, green: 0.933, blue: 0.949, alpha: 1.0)
            case "NormalKeyColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0) }
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            case "OpenKeyColor":
                if traits.userInterfaceStyle == .dark && traits.accessibilityContrast == .high { return UIColor(red: 0.0, green: 0.248, blue: 0.5, alpha: 1.0) }
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.0, green: 0.261, blue: 0.5, alpha: 1.0) }
                if traits.accessibilityContrast == .high { return UIColor(red: 0.582, green: 0.608, blue: 0.96, alpha: 1.0) }
                return UIColor(red: 0.707, green: 0.715, blue: 0.977, alpha: 1.0)
            case "RomanHighlightedKeyColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.224, green: 0.227, blue: 0.235, alpha: 1.0) }
                return UIColor(red: 0.926, green: 0.933, blue: 0.95, alpha: 1.0)
            case "RomanKeyColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.169, green: 0.173, blue: 0.18, alpha: 1.0) }
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            case "TabKeyColor":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0) }
                return UIColor(red: 0.804, green: 0.812, blue: 0.839, alpha: 1.0)
            case "TabKeyColor_iOS15":
                if traits.userInterfaceStyle == .dark { return UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0) }
                return UIColor(red: 0.776, green: 0.784, blue: 0.81, alpha: 1.0)
            default: return .clear
            }
        })
#else
        return Color(name)
#endif
    }
}
