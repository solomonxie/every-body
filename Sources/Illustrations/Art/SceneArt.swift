import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Pre-rendered scene pictures (Resources/Illustrations, WebP with alpha), decoded once and kept.
@MainActor
enum SceneArt {
    private static var cache: [String: Image] = [:]
    private static var missing: Set<String> = []

    static func image(_ name: String) -> Image? {
        if let log = ProcessInfo.processInfo.environment["ART_LOG"], let h = FileHandle(forWritingAtPath: log) { h.seekToEndOfFile(); h.write((name + "\n").data(using: .utf8)!); try? h.close() }
        if let hit = cache[name] { return hit }
        guard !missing.contains(name), let url = url(name), let data = try? Data(contentsOf: url) else {
            missing.insert(name)
            return nil
        }
        #if canImport(UIKit)
        guard let bitmap = UIImage(data: data)?.preparingForDisplay() else { missing.insert(name); return nil }
        let img = Image(uiImage: bitmap)
        #else
        guard let bitmap = NSImage(data: data) else { missing.insert(name); return nil }
        let img = Image(nsImage: bitmap)
        #endif
        cache[name] = img
        return img
    }

    /// app bundle, or $ART_DIR (Resources/Illustrations) for the Mac scene renderer
    private static func url(_ name: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: "webp") { return u }
        guard let dir = ProcessInfo.processInfo.environment["ART_DIR"] else { return nil }
        // Resources/Illustrations/<scene>/<scene>-….webp
        let scene = String(name.prefix { $0 != "-" })
        let u = URL(fileURLWithPath: dir).appendingPathComponent(scene).appendingPathComponent("\(name).webp")
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
}

extension Sketch {
    /// Full-frame pictures cross-faded by weight (weights sum to 1); false when none is available.
    @MainActor @discardableResult
    mutating func art(_ layers: [(name: String, weight: Double)]) -> Bool {
        if ProcessInfo.processInfo.environment["ART_LOG"] != nil { for l in layers { _ = SceneArt.image(l.name) } }
        let got = layers.filter { $0.weight > 0.001 }.compactMap { l in SceneArt.image(l.name).map { ($0, l.weight) } }
        guard !got.isEmpty else { return false }
        let frame = CGRect(origin: .zero, size: sceneSize)
        ctx.drawLayer { layer in
            // additive blend of weighted layers = an even cross-fade: shared parts stay put
            for (i, (img, w)) in got.enumerated() {
                var l = layer
                l.opacity = w
                if i > 0 { l.blendMode = .plusLighter }
                l.draw(img, in: frame)
            }
        }
        return true
    }
}

extension Illustrations {
    /// picture set showing the person affected; toddlers use the child's, babies are the same for both sexes
    static func artPerson(_ who: Profile) -> String {
        switch who.age {
        case .infant: "infant"
        case .toddler, .child: who.female ? "girl" : "child"
        case .senior: who.female ? "senior_woman" : "senior"
        case .adult: who.isPregnant ? "pregnant" : who.female ? "woman" : "adult"
        }
    }
}
