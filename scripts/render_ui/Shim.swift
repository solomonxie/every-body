import AppKit
import SwiftUI

// macOS stand-ins for the iOS-only APIs the app's screens use.
typealias UIColor = NSColor
typealias UIImage = NSImage

struct Traits { let userInterfaceStyle: Style; enum Style { case light, dark } }

extension NSColor {
    convenience init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    convenience init(_ provider: @escaping @Sendable (Traits) -> NSColor) {
        self.init(name: nil) { appearance in
            provider(Traits(userInterfaceStyle: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light))
        }
    }

    private static func pair(_ l: NSColor, _ d: NSColor) -> NSColor { NSColor { $0.userInterfaceStyle == .dark ? d : l } }
    private static func grey(_ w: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: w, green: w, blue: w, alpha: a) }

    static var systemBackground: NSColor { pair(.white, .black) }
    static var secondarySystemBackground: NSColor { pair(NSColor(hex: "#F2F2F7"), NSColor(hex: "#1C1C1E")) }
    static var systemGroupedBackground: NSColor { pair(NSColor(hex: "#F2F2F7"), .black) }
    static var secondarySystemGroupedBackground: NSColor { pair(.white, NSColor(hex: "#1C1C1E")) }
    static var systemFill: NSColor { pair(grey(0.47, 0.2), grey(0.47, 0.36)) }
    static var tertiarySystemFill: NSColor { pair(grey(0.46, 0.12), grey(0.46, 0.24)) }
    static var shimSeparator: NSColor { pair(grey(0.24, 0.29), grey(0.33, 0.6)) }
}

extension Color {
    init(uiColor: NSColor) { self.init(nsColor: uiColor) }
    init(hex: String) { self.init(nsColor: NSColor(hex: hex)) }
    init(light: String, dark: String) {
        let l = NSColor(hex: light), d = NSColor(hex: dark)
        self.init(nsColor: NSColor { $0.userInterfaceStyle == .dark ? d : l })
    }
    static let brand = Color(light: "#6C4F9E", dark: "#A98FE3")
    static let brandFill = Color(light: "#6C4F9E", dark: "#7458B8")
}

extension NSColor { static var separator: NSColor { shimSeparator } }

enum UIAccessibility { static let isReduceMotionEnabled = false }

enum ShimTitleMode { case inline, large, automatic }
extension View {
    func navigationBarTitleDisplayMode(_: ShimTitleMode) -> some View { self }
}

enum ShimDrawerMode { case always, automatic }
extension SearchFieldPlacement {
    static func navigationBarDrawer(displayMode: ShimDrawerMode) -> SearchFieldPlacement { .automatic }
}

extension ToolbarItemPlacement {
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
    static var topBarLeading: ToolbarItemPlacement { .automatic }
}

/// the real one lives with the RealityKit chart screen
struct ChartCanvas: View {
    let chart: ReflexChart
    let face: ChartFace
    let side: Side
    let zones: [ReflexZone]
    let selectedID: String?
    let showLabels: Bool
    var zh = true
    var flagged: Set<String> = []
    let zoom: CGFloat
    let pan: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: 30).fill(Color(hex: "#F5D7BF")).padding(12)
    }
}
