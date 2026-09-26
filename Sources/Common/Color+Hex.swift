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

    static let brand = Color(hex: "#6C4F9E")
}
