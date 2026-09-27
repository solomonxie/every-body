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
    // view options: not saved, every page starts from these defaults (resetViewOptions)
    var whiteBackground = false
    var autoRotate = true
    var female: Bool { didSet { save() } }
    var age: AgeGroup { didSet { save() } }
    var pregnant: Bool { didSet { save() } }
    /// the 3D figure's face and skin tone
    var heritage: Heritage { didSet { save() } }
    /// adults only; children always wear it
    var showUnderwear = true
    private(set) var recentSearches: [String] { didSet { save() } }

    private let store = UserDefaults.standard

    init() {
        names = NameMode(rawValue: store.string(forKey: "names") ?? "")
            ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zh : .en)
        female = store.bool(forKey: "female")
        age = AgeGroup(rawValue: store.string(forKey: "age") ?? "") ?? .adult
        pregnant = store.bool(forKey: "pregnant")
        heritage = Heritage(rawValue: store.string(forKey: "heritage") ?? "")
            ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .eastAsian : .white)
        recentSearches = store.stringArray(forKey: "recentSearches") ?? []
    }

    private func save() {
        store.set(names.rawValue, forKey: "names")
        store.set(female, forKey: "female")
        store.set(age.rawValue, forKey: "age")
        store.set(pregnant, forKey: "pregnant")
        store.set(heritage.rawValue, forKey: "heritage")
        store.set(recentSearches, forKey: "recentSearches")
    }

    /// Pages don't remember how they were last viewed.
    func resetViewOptions() {
        whiteBackground = false
        autoRotate = true
        showUnderwear = true
    }

    /// newest first, 6 kept
    func remember(search: String) {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        recentSearches = Array(([q] + recentSearches.filter { $0.caseInsensitiveCompare(q) != .orderedSame }).prefix(6))
    }

    func clearRecentSearches() { recentSearches = [] }

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
