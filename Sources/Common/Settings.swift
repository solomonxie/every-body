import SwiftUI

enum NameMode: String, CaseIterable {
    case en, zh, both
}

/// Persisted preferences.
@MainActor
@Observable
final class Settings {
    var names: NameMode { didSet { save() } }
    var whiteBackground: Bool { didSet { save() } }
    var autoRotate: Bool { didSet { save() } }
    var female: Bool { didSet { save() } }

    private let store = UserDefaults.standard

    init() {
        names = NameMode(rawValue: store.string(forKey: "names") ?? "") ?? .both
        whiteBackground = store.bool(forKey: "whiteBackground")
        autoRotate = store.object(forKey: "autoRotate") as? Bool ?? true
        female = store.bool(forKey: "female")
    }

    private func save() {
        store.set(names.rawValue, forKey: "names")
        store.set(whiteBackground, forKey: "whiteBackground")
        store.set(autoRotate, forKey: "autoRotate")
        store.set(female, forKey: "female")
    }

    /// "Femur · 股骨", "Femur" or "股骨"
    func name(_ en: String, _ zh: String) -> String {
        switch names {
        case .en: en
        case .zh: zh.isEmpty ? en : zh
        case .both: zh.isEmpty ? en : "\(en) · \(zh)"
        }
    }

    var showEn: Bool { names != .zh }
    var showZh: Bool { names != .en }
}
