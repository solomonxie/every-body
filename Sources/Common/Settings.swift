import SwiftUI

/// One language at a time, never mixed.
enum NameMode: String, CaseIterable {
    case en, zh
}

/// Persisted preferences.
@MainActor
@Observable
final class Settings {
    var names: NameMode { didSet { save() } }
    var whiteBackground: Bool { didSet { save() } }
    var autoRotate: Bool { didSet { save() } }
    var female: Bool { didSet { save() } }
    var age: AgeGroup { didSet { save() } }
    var pregnant: Bool { didSet { save() } }

    private let store = UserDefaults.standard

    init() {
        names = NameMode(rawValue: store.string(forKey: "names") ?? "")
            ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zh : .en)
        whiteBackground = store.bool(forKey: "whiteBackground")
        autoRotate = store.object(forKey: "autoRotate") as? Bool ?? true
        female = store.bool(forKey: "female")
        age = AgeGroup(rawValue: store.string(forKey: "age") ?? "") ?? .adult
        pregnant = store.bool(forKey: "pregnant")
    }

    private func save() {
        store.set(names.rawValue, forKey: "names")
        store.set(whiteBackground, forKey: "whiteBackground")
        store.set(autoRotate, forKey: "autoRotate")
        store.set(female, forKey: "female")
        store.set(age.rawValue, forKey: "age")
        store.set(pregnant, forKey: "pregnant")
    }

    var profile: Profile { Profile(age: age, female: female, pregnant: pregnant) }

    /// "Femur" or "股骨"
    func name(_ en: String, _ zh: String) -> String {
        names == .zh && !zh.isEmpty ? zh : en
    }

    var zh: Bool { names == .zh }

    func t(_ en: String, _ zh: String) -> String { name(en, zh) }
    func t(_ b: Bilingual) -> String { name(b.en, b.zh) }

    /// "Volume 血容量" → "Volume" or "血容量"
    func t(mixed: String) -> String { Bilingual.pick(mixed: mixed, zh: zh) }
}
