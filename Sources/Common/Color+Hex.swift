import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }

    /// follows light / dark mode
    init(light: String, dark: String) {
        let l = UIColor(hex: light), d = UIColor(hex: dark)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }

    /// text, tint, outlines
    static let brand = Color(light: "#6C4F9E", dark: "#A98FE3")
    /// solid fill under white text
    static let brandFill = Color(light: "#6C4F9E", dark: "#7458B8")
}
