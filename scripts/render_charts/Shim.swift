import AppKit
import SwiftUI

// macOS stand-ins for the app's UIKit helpers.
extension Color {
    init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

struct Bilingual: Sendable {
    let en: String
    let zh: String
    init(_ en: String, _ zh: String) { self.en = en; self.zh = zh }
}
