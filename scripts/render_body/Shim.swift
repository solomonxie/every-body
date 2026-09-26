import AppKit

// macOS stand-ins for the app's UIKit helpers.
typealias UIColor = NSColor

extension NSColor {
    convenience init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

struct Bilingual: Sendable {
    let en: String
    let zh: String
    init(_ en: String, _ zh: String) { self.en = en; self.zh = zh }
}
